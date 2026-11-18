//
//  LicenseManager.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import Foundation
import Combine

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isLicensed = false
    @Published var isTrialActive = false
    @Published var daysRemainingInTrial = 0
    @Published var customerName: String?
    @Published var customerEmail: String?
    
    var canUseApp: Bool { isLicensed || isTrialActive }
    
    let trialDays = 7
    let validationGraceDays = 30
    let maxConsecutiveFailures = 5
    private let retryDelays: [TimeInterval] = [3600, 21600, 86400] // 1h, 6h, 24h
    let defaults: UserDefaults
    private let session: URLSession
    private var retryTask: Task<Void, Never>?
    
    // Dodo Payments license API. These endpoints are public. An API key is not necessary.
    static let apiEndpoint = "https://live.dodopayments.com/licenses"
    
    // The Dodo Payments product ID of SleepBar. A key for a different product must not unlock the app.
    static let productId = "pdt_0NsEmbczmtMxeP3iZxFQb"
    
    // The value of Keys.licenseProvider for a license that Dodo Payments activated.
    static let dodoProvider = "dodo"
    
    enum Keys {
        static let firstLaunchDate = "firstLaunchDate"
        static let licenseKey = "licenseKey"
        static let instanceId = "instanceId"
        static let instanceName = "instanceName"
        static let lastValidationDate = "lastValidationDate"
        static let customerEmail = "customerEmail"
        static let customerName = "customerName"
        static let consecutiveValidationFailures = "consecutiveValidationFailures"
        static let licenseProvider = "licenseProvider"
    }
    
    private init() {
        self.defaults = .standard
        self.session = .shared
        checkLicenseStatus()
        startPeriodicValidation()
        startTrialRefresh()
    }
    
    init(defaults: UserDefaults, session: URLSession) {
        self.defaults = defaults
        self.session = session
    }
    
    // MARK: - License Status
    
    func checkLicenseStatus() {
        if defaults.string(forKey: Keys.licenseKey) != nil,
           defaults.string(forKey: Keys.instanceId) != nil {
            
            isLicensed = true
            customerEmail = defaults.string(forKey: Keys.customerEmail)
            customerName = defaults.string(forKey: Keys.customerName)
            
            if isLegacyLicense || shouldPerformValidation() {
                Task {
                    await refreshLicense()
                }
            }
            return
        }
        
        checkTrialStatus()
    }
    
    func shouldPerformValidation() -> Bool {
        guard let lastValidation = defaults.object(forKey: Keys.lastValidationDate) as? Date else {
            return true // Never validated, should validate now
        }
        
        let daysSinceLastValidation = Calendar.current.dateComponents([.day], from: lastValidation, to: Date()).day ?? 0
        return daysSinceLastValidation >= 3
    }
    
    private func startPeriodicValidation() {
        Timer.scheduledTimer(withTimeInterval: 259200, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                await self.refreshLicense()
            }
        }
    }
    
    // Versions before the move to Dodo Payments activated the license with Lemon Squeezy.
    var isLegacyLicense: Bool {
        defaults.string(forKey: Keys.licenseProvider) != Self.dodoProvider
    }
    
    // Ask the license server about the stored license.
    func refreshLicense() async {
        guard let licenseKey = defaults.string(forKey: Keys.licenseKey),
              let instanceId = defaults.string(forKey: Keys.instanceId) else {
            return
        }
        
        if isLegacyLicense {
            await migrateLegacyLicense(key: licenseKey)
        } else {
            await validateLicenseWithAPI(key: licenseKey, instanceId: instanceId)
        }
    }
    
    // The app can run for weeks without a relaunch. Check the trial each hour so that it ends on time.
    private func startTrialRefresh() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.refreshTrialStatus()
        }
    }

    func refreshTrialStatus() {
        guard !isLicensed else { return }
        checkTrialStatus()
    }

    func checkTrialStatus() {
        let firstLaunch = getFirstLaunchDate()
        let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        
        if daysSinceLaunch < trialDays {
            isTrialActive = true
            daysRemainingInTrial = trialDays - daysSinceLaunch
            isLicensed = false
        } else {
            isTrialActive = false
            daysRemainingInTrial = 0
            isLicensed = false
        }
    }
    
    func getFirstLaunchDate() -> Date {
        if let savedDate = defaults.object(forKey: Keys.firstLaunchDate) as? Date {
            return savedDate
        } else {
            let now = Date()
            defaults.set(now, forKey: Keys.firstLaunchDate)
            return now
        }
    }
    
    // MARK: - Dodo Payments API Integration
    
    struct Activation {
        let instanceId: String
        let productId: String?
        let customerName: String?
        let customerEmail: String?
    }
    
    enum ActivationResult {
        case activated(Activation)
        // The license server refused the key. The message is for the user.
        case rejected(String)
        case limitReached
        case connectivityError(String)
    }
    
    func activateLicense(key: String, email: String) async -> (success: Bool, error: String?) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Get unique instance name (computer name)
        let instanceName = Host.current().localizedName ?? "Mac"
        
        switch await requestActivation(key: normalizedKey, instanceName: instanceName) {
        case .activated(let activation):
            // SECURITY: Validate the product. If the check fails, release the instance,
            // because a failed attempt must not use one of the activations of the key.
            guard activation.productId == Self.productId else {
                _ = await requestDeactivation(key: normalizedKey, instanceId: activation.instanceId)
                return (false, "This license key is not valid for SleepBar")
            }
            
            // SECURITY: Validate customer email
            if let customerEmail = activation.customerEmail,
               customerEmail.lowercased() != normalizedEmail {
                _ = await requestDeactivation(key: normalizedKey, instanceId: activation.instanceId)
                return (false, "Email address does not match the purchase email")
            }
            
            defaults.set(instanceName, forKey: Keys.instanceName)
            storeActivation(activation, key: normalizedKey)
            
            await MainActor.run {
                self.isLicensed = true
                self.isTrialActive = false
                self.daysRemainingInTrial = 0
                self.customerName = activation.customerName
                self.customerEmail = activation.customerEmail
            }
            
            TelemetryManager.shared.track("license_activated")
            
            return (true, nil)
            
        case .rejected(let message):
            return (false, message)
            
        case .limitReached:
            return (false, "This license key is in use on the maximum number of Macs. Deactivate it on one Mac, then try again.")
            
        case .connectivityError(let reason):
            return (false, reason)
        }
    }
    
    private func storeActivation(_ activation: Activation, key: String) {
        defaults.set(key, forKey: Keys.licenseKey)
        defaults.set(activation.instanceId, forKey: Keys.instanceId)
        defaults.set(Self.dodoProvider, forKey: Keys.licenseProvider)
        defaults.set(Date(), forKey: Keys.lastValidationDate)
        defaults.set(0, forKey: Keys.consecutiveValidationFailures)
        
        if let customerName = activation.customerName {
            defaults.set(customerName, forKey: Keys.customerName)
        }
        if let customerEmail = activation.customerEmail {
            defaults.set(customerEmail, forKey: Keys.customerEmail)
        }
    }
    
    // The Lemon Squeezy keys are imported into Dodo Payments, but the activations are not.
    // Activate the stored key again, and the customer does not see a change.
    private func migrateLegacyLicense(key: String) async {
        let instanceName = defaults.string(forKey: Keys.instanceName) ?? Host.current().localizedName ?? "Mac"
        
        switch await requestActivation(key: key, instanceName: instanceName) {
        case .activated(let activation):
            guard activation.productId == Self.productId else {
                print("[LicenseManager] Stored license key is for a different product")
                _ = await requestDeactivation(key: key, instanceId: activation.instanceId)
                await revokeLicense()
                return
            }
            
            storeActivation(activation, key: key)
            await MainActor.run {
                self.customerName = self.defaults.string(forKey: Keys.customerName)
                self.customerEmail = self.defaults.string(forKey: Keys.customerEmail)
            }
            
        case .rejected(let message):
            print("[LicenseManager] License server refused the stored license key: \(message)")
            await revokeLicense()
            
        case .limitReached:
            // An earlier attempt can use an activation and then lose the response.
            // Keep the license, because the customer did nothing wrong.
            print("[LicenseManager] Activation limit reached for the stored license key. Keeping license active")
            
        case .connectivityError(let reason):
            // The next launch or the periodic check tries again.
            print("[LicenseManager] Could not move the stored license key: \(reason)")
        }
    }
    
    private func revokeLicense() async {
        clearLicenseData()
        await MainActor.run {
            self.isLicensed = false
            self.checkTrialStatus()
        }
    }
    
    private func post(_ path: String, body: [String: String]) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(Self.apiEndpoint)/\(path)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
    
    func parseActivation(_ data: Data) -> Activation? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let instanceId = json["id"] as? String else {
            return nil
        }
        
        let product = json["product"] as? [String: Any]
        let customer = json["customer"] as? [String: Any]
        return Activation(
            instanceId: instanceId,
            productId: product?["product_id"] as? String,
            customerName: customer?["name"] as? String,
            customerEmail: customer?["email"] as? String
        )
    }
    
    private func requestActivation(key: String, instanceName: String) async -> ActivationResult {
        do {
            let (data, response) = try await post("activate", body: ["license_key": key, "name": instanceName])
            
            switch response.statusCode {
            case 200, 201:
                guard let activation = parseActivation(data) else {
                    return .connectivityError("Activation failed: the response is not complete")
                }
                return .activated(activation)
            case 403:
                return .rejected("This license key is not active")
            case 404:
                return .rejected("License key not found")
            case 422:
                return .limitReached
            default:
                return .connectivityError("Activation failed (HTTP \(response.statusCode))")
            }
        } catch {
            return .connectivityError("Network error: \(error.localizedDescription)")
        }
    }
    
    private func requestDeactivation(key: String, instanceId: String) async -> Bool {
        do {
            let (_, response) = try await post("deactivate", body: ["license_key": key, "license_key_instance_id": instanceId])
            // 403 and 404 mean that the server does not have this instance. There is nothing to release.
            return [200, 403, 404].contains(response.statusCode)
        } catch {
            print("Deactivation error: \(error)")
            return false
        }
    }
    
    func isWithinValidationGracePeriod() -> Bool {
        guard let lastValidation = defaults.object(forKey: Keys.lastValidationDate) as? Date else {
            return false
        }
        let daysSinceValidation = Calendar.current.dateComponents([.day], from: lastValidation, to: Date()).day ?? Int.max
        return daysSinceValidation < validationGraceDays
    }
    
    func applyGracePeriodOrInvalidate() {
        let failures = defaults.integer(forKey: Keys.consecutiveValidationFailures)
        
        if isWithinValidationGracePeriod() || failures < maxConsecutiveFailures {
            print("[LicenseManager] Keeping license active — grace period: \(isWithinValidationGracePeriod()), failures: \(failures)/\(maxConsecutiveFailures)")
            isLicensed = true
            customerEmail = defaults.string(forKey: Keys.customerEmail)
            customerName = defaults.string(forKey: Keys.customerName)
        } else {
            print("[LicenseManager] License invalidated — grace period expired and \(failures) consecutive failures")
            isLicensed = false
            checkTrialStatus()
        }
    }
    
    private enum ValidationResult {
        case valid
        case invalid
        case connectivityError(String)
    }
    
    private func validateLicenseWithAPI(key: String, instanceId: String) async {
        let result = await performValidationRequest(key: key, instanceId: instanceId)
        
        if case .connectivityError(let reason) = result {
            print("[LicenseManager] \(reason). Scheduling retries")
            scheduleRetries(key: key, instanceId: instanceId)
            return
        }
        
        retryTask?.cancel()
        retryTask = nil
        await applyValidation(result)
    }
    
    private func applyValidation(_ result: ValidationResult) async {
        switch result {
        case .valid:
            defaults.set(Date(), forKey: Keys.lastValidationDate)
            defaults.set(0, forKey: Keys.consecutiveValidationFailures)
            await MainActor.run {
                self.isLicensed = true
                self.isTrialActive = false
                self.daysRemainingInTrial = 0
            }
            
        case .invalid:
            print("[LicenseManager] License server reports that the license is not valid")
            await revokeLicense()
            
        case .connectivityError:
            break
        }
    }
    
    private func scheduleRetries(key: String, instanceId: String) {
        retryTask?.cancel()
        retryTask = Task {
            for (index, delay) in retryDelays.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
                
                let result = await performValidationRequest(key: key, instanceId: instanceId)
                if case .connectivityError(let reason) = result {
                    print("[LicenseManager] Retry \(index + 1)/\(retryDelays.count) failed: \(reason)")
                    continue
                }
                
                await applyValidation(result)
                return
            }
            
            // All retries exhausted. Count it as a real failure.
            if !Task.isCancelled {
                print("[LicenseManager] All retries exhausted")
                recordValidationFailure()
                applyGracePeriodOrInvalidate()
            }
        }
    }
    
    private func performValidationRequest(key: String, instanceId: String) async -> ValidationResult {
        do {
            let (data, response) = try await post("validate", body: ["license_key": key, "license_key_instance_id": instanceId])
            
            guard response.statusCode == 200 else {
                return .connectivityError("HTTP \(response.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool else {
                return .connectivityError("Response missing expected fields")
            }
            
            return valid ? .valid : .invalid
        } catch {
            return .connectivityError("Network error: \(error.localizedDescription)")
        }
    }
    
    func clearLicenseData() {
        defaults.removeObject(forKey: Keys.licenseKey)
        defaults.removeObject(forKey: Keys.instanceId)
        defaults.removeObject(forKey: Keys.instanceName)
        defaults.removeObject(forKey: Keys.lastValidationDate)
        defaults.removeObject(forKey: Keys.consecutiveValidationFailures)
        defaults.removeObject(forKey: Keys.licenseProvider)
    }
    
    func recordValidationFailure() {
        let current = defaults.integer(forKey: Keys.consecutiveValidationFailures)
        defaults.set(current + 1, forKey: Keys.consecutiveValidationFailures)
    }
    
    func deactivateLicense() async -> Bool {
        guard let key = defaults.string(forKey: Keys.licenseKey),
              let instanceId = defaults.string(forKey: Keys.instanceId) else {
            return false
        }
        
        // A Lemon Squeezy activation has no instance at Dodo Payments. There is nothing to release.
        if !isLegacyLicense {
            guard await requestDeactivation(key: key, instanceId: instanceId) else {
                return false
            }
        }
        
        clearLicenseData()
        defaults.removeObject(forKey: Keys.customerEmail)
        defaults.removeObject(forKey: Keys.customerName)
        
        TelemetryManager.shared.track("license_deactivated")
        
        await MainActor.run {
            self.checkLicenseStatus()
        }
        return true
    }
    
    var licenseKey: String? {
        defaults.string(forKey: Keys.licenseKey)
    }
    
    // MARK: - Developer Tools (for testing only)
    
    #if DEBUG
    func resetTrial() {
        defaults.removeObject(forKey: Keys.firstLaunchDate)
        defaults.removeObject(forKey: Keys.licenseKey)
        defaults.removeObject(forKey: Keys.instanceId)
        defaults.removeObject(forKey: Keys.instanceName)
        defaults.removeObject(forKey: Keys.lastValidationDate)
        defaults.removeObject(forKey: Keys.customerEmail)
        defaults.removeObject(forKey: Keys.customerName)
        defaults.removeObject(forKey: Keys.consecutiveValidationFailures)
        defaults.removeObject(forKey: Keys.licenseProvider)
        
        Task { @MainActor in
            self.isLicensed = false
            self.isTrialActive = true
            self.daysRemainingInTrial = self.trialDays
            self.customerName = nil
            self.customerEmail = nil
        }
        
        checkLicenseStatus()
    }
    
    func expireTrialForTesting() {
        // Set first launch date to 8 days ago (past the 7-day trial)
        let expiredDate = Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date()
        defaults.set(expiredDate, forKey: Keys.firstLaunchDate)
        
        // Clear any license
        defaults.removeObject(forKey: Keys.licenseKey)
        defaults.removeObject(forKey: Keys.instanceId)
        defaults.removeObject(forKey: Keys.instanceName)
        defaults.removeObject(forKey: Keys.licenseProvider)
        
        checkLicenseStatus()
    }
    
    func generateTestLicenseKey(for email: String) -> String {
        // For testing: Generate a fake license key format
        // In production, real keys come from Dodo Payments
        let randomString = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
        let key = stride(from: 0, to: 16, by: 4)
            .map { i in
                let start = randomString.index(randomString.startIndex, offsetBy: i)
                let end = randomString.index(start, offsetBy: 4)
                return String(randomString[start..<end])
            }
            .joined(separator: "-")
            .uppercased()
        
        return key
    }
    #endif
}

