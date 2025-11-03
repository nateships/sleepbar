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
    
    private let trialDays = 7
    private let defaults = UserDefaults.standard
    
    // Lemon Squeezy API
    private let apiEndpoint = "https://api.lemonsqueezy.com/v1/licenses"
    
    // CRITICAL: Set these to your actual Lemon Squeezy IDs
    // Get these from your Lemon Squeezy dashboard
    private let expectedStoreId = 237783  // TODO: Replace with your actual store ID
    private let expectedProductId = 681433  // TODO: Replace with your actual product ID
    // Optional: Set this if you want to validate specific variant
    private let expectedVariantId: Int? = nil  // TODO: Replace with variant ID if needed
    
    private enum Keys {
        static let firstLaunchDate = "firstLaunchDate"
        static let licenseKey = "licenseKey"
        static let instanceId = "instanceId"
        static let instanceName = "instanceName"
        static let lastValidationDate = "lastValidationDate"
        static let customerEmail = "customerEmail"
        static let customerName = "customerName"
    }
    
    private init() {
        checkLicenseStatus()
        startPeriodicValidation()
    }
    
    // MARK: - License Status
    
    func checkLicenseStatus() {
        // Check if already licensed
        if let licenseKey = defaults.string(forKey: Keys.licenseKey),
           let instanceId = defaults.string(forKey: Keys.instanceId) {
            // Check if we need to revalidate (every 24 hours)
            let shouldValidate = shouldPerformValidation()
            
            if shouldValidate {
                // Validate with Lemon Squeezy API
                Task {
                    await validateLicenseWithAPI(key: licenseKey, instanceId: instanceId)
                }
            } else {
                // Use cached license status
                DispatchQueue.main.async {
                    self.isLicensed = true
                    self.customerEmail = self.defaults.string(forKey: Keys.customerEmail)
                    self.customerName = self.defaults.string(forKey: Keys.customerName)
                }
            }
            return
        }
        
        // Check trial status
        checkTrialStatus()
    }
    
    private func shouldPerformValidation() -> Bool {
        guard let lastValidation = defaults.object(forKey: Keys.lastValidationDate) as? Date else {
            return true // Never validated, should validate now
        }
        
        // Validate every 24 hours
        let hoursSinceLastValidation = Calendar.current.dateComponents([.hour], from: lastValidation, to: Date()).hour ?? 0
        return hoursSinceLastValidation >= 24
    }
    
    private func startPeriodicValidation() {
        // Validate license every 24 hours
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
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
    
    private func checkTrialStatus() {
        let firstLaunch = getFirstLaunchDate()
        let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        
        DispatchQueue.main.async {
            if daysSinceLaunch < self.trialDays {
                self.isTrialActive = true
                self.daysRemainingInTrial = self.trialDays - daysSinceLaunch
                self.isLicensed = false
            } else {
                self.isTrialActive = false
                self.daysRemainingInTrial = 0
                self.isLicensed = false
            }
        }
    }
    
    private func getFirstLaunchDate() -> Date {
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
            
            // Save license data
            defaults.set(normalizedKey, forKey: Keys.licenseKey)
            defaults.set(instanceId, forKey: Keys.instanceId)
            defaults.set(instanceName, forKey: Keys.instanceName)
            
            // Save customer information
            if let customerName = meta["customer_name"] as? String {
                defaults.set(customerName, forKey: Keys.customerName)
            }
            if let customerEmail = meta["customer_email"] as? String {
                defaults.set(customerEmail, forKey: Keys.customerEmail)
            }
            
            // Update status
            await validateLicenseWithAPI(key: normalizedKey, instanceId: instanceId)
            return (true, nil)
        }
        
        return (false, result.error ?? "Failed to activate license")
    }
    
    private func validateProductIds(meta: [String: Any]) -> Bool {
        // Validate store ID
        if let storeId = meta["store_id"] as? Int, storeId != expectedStoreId {
            return false
        }
        
        // Validate product ID
        if let productId = meta["product_id"] as? Int, productId != expectedProductId {
            return false
        }
        
        // Validate variant ID if specified
        if let expectedVariant = expectedVariantId,
           let variantId = meta["variant_id"] as? Int,
           variantId != expectedVariant {
            return false
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
        
        let params = "license_key=\(key)&instance_name=\(instanceName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? instanceName)"
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
    
    private func validateLicenseWithAPI(key: String, instanceId: String) async {
        guard let url = URL(string: "\(apiEndpoint)/validate") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = "license_key=\(key)&instance_id=\(instanceId)"
        request.httpBody = params.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.isLicensed = false
                    self.checkTrialStatus()
                }
                return
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let valid = json?["valid"] as? Bool ?? false
            let licenseKey = json?["license_key"] as? [String: Any]
            let status = licenseKey?["status"] as? String
            let meta = json?["meta"] as? [String: Any]
            
            // SECURITY: Validate product/store IDs
            var isValidProduct = true
            if let meta = meta {
                isValidProduct = validateProductIds(meta: meta)
            }
            
            let customerName = meta?["customer_name"] as? String
            let customerEmail = meta?["customer_email"] as? String
            
            // Record validation timestamp
            defaults.set(Date(), forKey: Keys.lastValidationDate)
            
            DispatchQueue.main.async {
                // Only consider "active" status as licensed (not "inactive")
                // Other statuses: "expired", "disabled" = not licensed
                self.isLicensed = valid && isValidProduct && status == "active"
                self.licenseStatus = status
                self.customerName = customerName
                self.customerEmail = customerEmail
                
                if !self.isLicensed {
                    self.checkTrialStatus()
                }
            }
            
            // Save customer info for offline access
            if let customerName = customerName {
                defaults.set(customerName, forKey: Keys.customerName)
            }
            if let customerEmail = customerEmail {
                defaults.set(customerEmail, forKey: Keys.customerEmail)
            }
        } catch {
            DispatchQueue.main.async {
                self.isLicensed = false
                self.checkTrialStatus()
            }
        }
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
        
        let params = "license_key=\(key)&instance_id=\(instanceId)"
        request.httpBody = params.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Clear all license-related local data
                defaults.removeObject(forKey: Keys.licenseKey)
                defaults.removeObject(forKey: Keys.instanceId)
                defaults.removeObject(forKey: Keys.instanceName)
                defaults.removeObject(forKey: Keys.lastValidationDate)
                defaults.removeObject(forKey: Keys.customerEmail)
                defaults.removeObject(forKey: Keys.customerName)
                
                DispatchQueue.main.async {
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
        
        DispatchQueue.main.async {
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

