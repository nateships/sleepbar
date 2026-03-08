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
    @Published var licenseStatus: String?
    @Published var customerName: String?
    @Published var customerEmail: String?
    
    var canUseApp: Bool { isLicensed || isTrialActive }
    
    let trialDays = 7
    let validationGraceDays = 30
    let maxConsecutiveFailures = 5
    private let retryDelays: [TimeInterval] = [3600, 21600, 86400] // 1h, 6h, 24h
    let defaults: UserDefaults
    private var retryTask: Task<Void, Never>?
    
    // Lemon Squeezy API
    private let apiEndpoint = "https://api.lemonsqueezy.com/v1/licenses"
    
    // CRITICAL: Set these to your actual Lemon Squeezy IDs
    // Get these from your Lemon Squeezy dashboard
    private let expectedStoreId = 237783  // TODO: Replace with your actual store ID
    private let expectedProductId = 681433  // TODO: Replace with your actual product ID
    // Optional: Set this if you want to validate specific variant
    private let expectedVariantId: Int? = nil  // TODO: Replace with variant ID if needed
    
    private static let formSafeCharacters: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return allowed
    }()
    
    func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: Self.formSafeCharacters) ?? value
    }
    
    enum Keys {
        static let firstLaunchDate = "firstLaunchDate"
        static let licenseKey = "licenseKey"
        static let instanceId = "instanceId"
        static let instanceName = "instanceName"
        static let lastValidationDate = "lastValidationDate"
        static let customerEmail = "customerEmail"
        static let customerName = "customerName"
        static let consecutiveValidationFailures = "consecutiveValidationFailures"
    }
    
    private init() {
        self.defaults = .standard
        checkLicenseStatus()
        startPeriodicValidation()
    }
    
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    
    // MARK: - License Status
    
    func checkLicenseStatus() {
        if let licenseKey = defaults.string(forKey: Keys.licenseKey),
           let instanceId = defaults.string(forKey: Keys.instanceId) {
            
            isLicensed = true
            customerEmail = defaults.string(forKey: Keys.customerEmail)
            customerName = defaults.string(forKey: Keys.customerName)
            
            if shouldPerformValidation() {
                Task {
                    await validateLicenseWithAPI(key: licenseKey, instanceId: instanceId)
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
            guard let self = self,
                  let licenseKey = self.defaults.string(forKey: Keys.licenseKey),
                  let instanceId = self.defaults.string(forKey: Keys.instanceId) else {
                return
            }
            
            Task {
                await self.validateLicenseWithAPI(key: licenseKey, instanceId: instanceId)
            }
        }
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
    
    // MARK: - Lemon Squeezy API Integration
    
    func activateLicense(key: String, email: String) async -> (success: Bool, error: String?) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Get unique instance name (computer name)
        let instanceName = Host.current().localizedName ?? "Mac"
        
        let result = await activateLicenseWithAPI(key: normalizedKey, instanceName: instanceName)
        
        if result.success, let instanceId = result.instanceId, let meta = result.meta {
            // SECURITY: Validate product/store IDs
            if !validateProductIds(meta: meta) {
                return (false, "This license key is not valid for SleepBar")
            }
            
            // SECURITY: Validate customer email
            if let customerEmail = meta["customer_email"] as? String {
                if customerEmail.lowercased() != normalizedEmail {
                    return (false, "Email address does not match the purchase email")
                }
            }
            
            defaults.set(normalizedKey, forKey: Keys.licenseKey)
            defaults.set(instanceId, forKey: Keys.instanceId)
            defaults.set(instanceName, forKey: Keys.instanceName)
            defaults.set(Date(), forKey: Keys.lastValidationDate)
            defaults.set(0, forKey: Keys.consecutiveValidationFailures)
            
            if let customerName = meta["customer_name"] as? String {
                defaults.set(customerName, forKey: Keys.customerName)
            }
            if let customerEmail = meta["customer_email"] as? String {
                defaults.set(customerEmail, forKey: Keys.customerEmail)
            }
            
            await MainActor.run {
                self.isLicensed = true
                self.isTrialActive = false
                self.daysRemainingInTrial = 0
                self.customerName = meta["customer_name"] as? String
                self.customerEmail = meta["customer_email"] as? String
            }
            
            TelemetryManager.shared.track("license_activated")
            
            return (true, nil)
        }
        
        return (false, result.error ?? "Failed to activate license")
    }
    
    func validateProductIds(meta: [String: Any]) -> Bool {
        guard let storeId = meta["store_id"] as? Int, storeId == expectedStoreId else {
            return false
        }
        
        guard let productId = meta["product_id"] as? Int, productId == expectedProductId else {
            return false
        }
        
        if let expectedVariant = expectedVariantId {
            guard let variantId = meta["variant_id"] as? Int, variantId == expectedVariant else {
                return false
            }
        }
        
        return true
    }
    
    private func activateLicenseWithAPI(key: String, instanceName: String) async -> (success: Bool, instanceId: String?, meta: [String: Any]?, error: String?) {
        guard let url = URL(string: "\(apiEndpoint)/activate") else {
            return (false, nil, nil, "Invalid API endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = "license_key=\(formEncode(key))&instance_name=\(formEncode(instanceName))"
        request.httpBody = params.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, nil, nil, "Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let instance = json?["instance"] as? [String: Any]
                let instanceId = instance?["id"] as? String
                let meta = json?["meta"] as? [String: Any]
                return (true, instanceId, meta, nil)
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let error = json?["error"] as? String ?? "Activation failed"
                return (false, nil, nil, error)
            }
        } catch {
            return (false, nil, nil, "Network error: \(error.localizedDescription)")
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
        case valid(status: String, customerName: String?, customerEmail: String?)
        case invalid(valid: Bool, status: String, isValidProduct: Bool)
        case connectivityError(String)
    }
    
    private func validateLicenseWithAPI(key: String, instanceId: String) async {
        let result = await performValidationRequest(key: key, instanceId: instanceId)
        
        switch result {
        case .valid(let status, let customerName, let customerEmail):
            retryTask?.cancel()
            retryTask = nil
            defaults.set(Date(), forKey: Keys.lastValidationDate)
            defaults.set(0, forKey: Keys.consecutiveValidationFailures)
            
            if let customerName = customerName {
                defaults.set(customerName, forKey: Keys.customerName)
            }
            if let customerEmail = customerEmail {
                defaults.set(customerEmail, forKey: Keys.customerEmail)
            }
            
            await MainActor.run {
                self.isLicensed = true
                self.licenseStatus = status
                self.customerName = customerName
                self.customerEmail = customerEmail
                self.isTrialActive = false
                self.daysRemainingInTrial = 0
            }
            
        case .invalid(let valid, let status, let isValidProduct):
            retryTask?.cancel()
            retryTask = nil
            print("[LicenseManager] License invalid — valid: \(valid), status: \(status), isValidProduct: \(isValidProduct)")
            defaults.set(0, forKey: Keys.consecutiveValidationFailures)
            clearLicenseData()
            await MainActor.run {
                self.isLicensed = false
                self.licenseStatus = status
                self.checkTrialStatus()
            }
            
        case .connectivityError(let reason):
            print("[LicenseManager] \(reason) — scheduling retries")
            scheduleRetries(key: key, instanceId: instanceId)
        }
    }
    
    private func scheduleRetries(key: String, instanceId: String) {
        retryTask?.cancel()
        retryTask = Task {
            for (index, delay) in retryDelays.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
                
                let result = await performValidationRequest(key: key, instanceId: instanceId)
                switch result {
                case .valid(let status, let customerName, let customerEmail):
                    defaults.set(Date(), forKey: Keys.lastValidationDate)
                    defaults.set(0, forKey: Keys.consecutiveValidationFailures)
                    if let customerName = customerName {
                        defaults.set(customerName, forKey: Keys.customerName)
                    }
                    if let customerEmail = customerEmail {
                        defaults.set(customerEmail, forKey: Keys.customerEmail)
                    }
                    await MainActor.run {
                        self.isLicensed = true
                        self.licenseStatus = status
                        self.customerName = customerName
                        self.customerEmail = customerEmail
                        self.isTrialActive = false
                        self.daysRemainingInTrial = 0
                    }
                    print("[LicenseManager] Retry \(index + 1) succeeded")
                    return
                    
                case .invalid(let valid, let status, let isValidProduct):
                    print("[LicenseManager] Retry \(index + 1) — license invalid: valid=\(valid), status=\(status), isValidProduct=\(isValidProduct)")
                    defaults.set(0, forKey: Keys.consecutiveValidationFailures)
                    clearLicenseData()
                    await MainActor.run {
                        self.isLicensed = false
                        self.licenseStatus = status
                        self.checkTrialStatus()
                    }
                    return
                    
                case .connectivityError(let reason):
                    print("[LicenseManager] Retry \(index + 1)/\(retryDelays.count) failed — \(reason)")
                    continue
                }
            }
            
            // All retries exhausted — now count it as a real failure
            if !Task.isCancelled {
                print("[LicenseManager] All retries exhausted")
                recordValidationFailure()
                applyGracePeriodOrInvalidate()
            }
        }
    }
    
    private func performValidationRequest(key: String, instanceId: String) async -> ValidationResult {
        guard let url = URL(string: "\(apiEndpoint)/validate") else {
            return .connectivityError("Invalid API endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = "license_key=\(formEncode(key))&instance_id=\(formEncode(instanceId))"
        request.httpBody = params.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                return .connectivityError("HTTP \(statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool,
                  let licenseKeyObj = json["license_key"] as? [String: Any],
                  let status = licenseKeyObj["status"] as? String else {
                return .connectivityError("Response missing expected fields")
            }
            
            let meta = json["meta"] as? [String: Any]
            
            var isValidProduct = true
            if let meta = meta {
                isValidProduct = validateProductIds(meta: meta)
            }
            
            let isActive = valid && isValidProduct && status == "active"
            
            if isActive {
                return .valid(
                    status: status,
                    customerName: meta?["customer_name"] as? String,
                    customerEmail: meta?["customer_email"] as? String
                )
            } else {
                return .invalid(valid: valid, status: status, isValidProduct: isValidProduct)
            }
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
        
        guard let url = URL(string: "\(apiEndpoint)/deactivate") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = "license_key=\(formEncode(key))&instance_id=\(formEncode(instanceId))"
        request.httpBody = params.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                 defaults.removeObject(forKey: Keys.licenseKey)
                defaults.removeObject(forKey: Keys.instanceId)
                defaults.removeObject(forKey: Keys.instanceName)
                defaults.removeObject(forKey: Keys.lastValidationDate)
                defaults.removeObject(forKey: Keys.customerEmail)
                defaults.removeObject(forKey: Keys.customerName)
                defaults.removeObject(forKey: Keys.consecutiveValidationFailures)
                
                TelemetryManager.shared.track("license_deactivated")
                
                await MainActor.run {
                    self.checkLicenseStatus()
                }
                return true
            }
        } catch {
            print("Deactivation error: \(error)")
        }
        
        return false
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
        
        Task { @MainActor in
            self.isLicensed = false
            self.isTrialActive = true
            self.daysRemainingInTrial = self.trialDays
            self.licenseStatus = nil
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
        
        checkLicenseStatus()
    }
    
    func generateTestLicenseKey(for email: String) -> String {
        // For testing: Generate a fake license key format
        // In production, real keys come from Lemon Squeezy
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

