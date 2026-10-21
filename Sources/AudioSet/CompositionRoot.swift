import AudioSetCore
import AudioSetInfrastructure

/// Composition root: единственное место, где порты связываются с адаптерами.
enum CompositionRoot {
    static func makeProfileService() throws -> ProfileService {
        return try ProfileService(
            store: FileSystemProfileStore(),
            gateway: CoreAudioVolumeGateway(),
            defaultProfiles: DefaultProfiles.standard,
            defaultProfileSetVersion: DefaultProfiles.setVersion)
    }
}
