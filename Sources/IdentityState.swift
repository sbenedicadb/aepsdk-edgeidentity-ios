//
// Copyright 2021 Adobe. All rights reserved.
// This file is licensed to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy
// of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
// OF ANY KIND, either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
//

import AEPCore
import AEPServices
import Foundation

/// Manages the business logic of the Identity extension
class IdentityState {
    private let LOG_TAG = "IdentityState"
    private(set) var hasBooted = false
    #if DEBUG
    var identityProperties: IdentityProperties
    #else
    private(set) var identityProperties: IdentityProperties
    #endif

    /// Creates a new `IdentityState` with the given identity properties
    /// - Parameter identityProperties: identity properties
    init(identityProperties: IdentityProperties) {
        self.identityProperties = identityProperties
    }

    /// Completes init for the Identity extension.
    /// - Parameters:
    ///   - configSharedState: the current configuration shared state available at registration time
    ///   - event: The `Event` triggering the bootup
    /// - Returns: True if we should share state after bootup, false otherwise
    func bootupIfReady(configSharedState: [String: Any], event: Event) -> Bool {

        // load data from local storage
        identityProperties.loadFromPersistence()

        // Load privacy status
        let privacyStatusString = configSharedState[IdentityEdgeConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String ?? ""
        identityProperties.privacyStatus = PrivacyStatus(rawValue: privacyStatusString) ?? IdentityEdgeConstants.Defaults.PRIVACY_STATUS

        // Generate new ECID if privacy status allows
        if identityProperties.privacyStatus != .optedOut && identityProperties.ecid == nil {
            identityProperties.ecid = ECID()
        }

        hasBooted = true
        Log.debug(label: LOG_TAG, "Identity has successfully booted up")
        return true
    }

    /// Updates and makes any required actions when the privacy status has updated
    /// - Parameters:
    ///   - event: the event triggering the privacy change
    ///   - createSharedState: a function which can create Identity shared state
    func processPrivacyChange(event: Event, createSharedState: ([String: Any], Event) -> Void, createXDMSharedState: ([String: Any], Event) -> Void) {
        let privacyStatusStr = event.data?[IdentityEdgeConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String ?? ""
        let newPrivacyStatus = PrivacyStatus(rawValue: privacyStatusStr) ?? PrivacyStatus.unknown

        if newPrivacyStatus == identityProperties.privacyStatus {
            return
        }

        identityProperties.privacyStatus = newPrivacyStatus

        if newPrivacyStatus == .optedOut {
            identityProperties.ecid = nil
            identityProperties.saveToPersistence()
            createSharedState(identityProperties.toEventData(), event)
            createXDMSharedState(identityProperties.toXdmData(), event)
        } else if identityProperties.ecid == nil {
            // When changing privacy status from optedout, need to generate a new Experience Cloud ID for the user
            identityProperties.ecid = ECID()
            identityProperties.saveToPersistence()
            createSharedState(identityProperties.toEventData(), event)
            createXDMSharedState(identityProperties.toXdmData(), event)
        }

    }

}