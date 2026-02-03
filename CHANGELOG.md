## [12.51.2](https://github.com/desaianand1/BatteryBoi-Recharged/compare/v12.51.1...v12.51.2) (2026-02-03)

### Bug Fixes

* **fastlane:** correct notarize action parameters for notarytool ([f15cd68](https://github.com/desaianand1/BatteryBoi-Recharged/commit/f15cd689ac1d4790c0b2f6ee193f36da0c15fe77))

## [12.51.1](https://github.com/desaianand1/BatteryBoi-Recharged/compare/v12.51.0...v12.51.1) (2026-02-03)

### Bug Fixes

* **release:** disable PR success comments to prevent 404 errors ([be08992](https://github.com/desaianand1/BatteryBoi-Recharged/commit/be0899203e5e3f9e9833c826443c720086e33a3a))

## 1.0.0 (2026-02-03)

### ⚠ BREAKING CHANGES

* **project-rename:** name change WILL cause issues due to package name change and old URLs being altered

### Features

* **a11y:** add accessibility and reduced motion support to views ([3b24031](https://github.com/desaianand1/BatteryBoi-Recharged/commit/3b240313b680258e0b233b56bd9b1a39c42f388f))
* **arch:** add AppEnvironment container ([2d69342](https://github.com/desaianand1/BatteryBoi-Recharged/commit/2d693429d484bb7c66965ba70e3a64a771b5c628))
* **arch:** add protocol conformance to managers ([d1fb69e](https://github.com/desaianand1/BatteryBoi-Recharged/commit/d1fb69ec8dbd0233de57784c66c850924bb7ed00))
* **arch:** add service protocols for dependency injection ([66b6e16](https://github.com/desaianand1/BatteryBoi-Recharged/commit/66b6e1662b14855e25ea4120075f5fb514ded0a7))
* **battery:** add native IOKit battery service ([43ecb08](https://github.com/desaianand1/BatteryBoi-Recharged/commit/43ecb08042a6a9b413e75ba648e749dad5426910))
* **bluetooth:** add native IOKit Bluetooth service ([082f4ac](https://github.com/desaianand1/BatteryBoi-Recharged/commit/082f4ac55669d2005f1d0ce4af0eb9ef2cf27b20))
* **concurrency:** add async timer infrastructure ([2c54b3f](https://github.com/desaianand1/BatteryBoi-Recharged/commit/2c54b3fafb05ef1f7a9006c16575ff4c3b337782))
* **design:** add design tokens and dark mode color assets ([75c63b6](https://github.com/desaianand1/BatteryBoi-Recharged/commit/75c63b643983764cf134260f84ac0929efea922f))
* **i18n:** add localization strings for new UI elements ([6e95870](https://github.com/desaianand1/BatteryBoi-Recharged/commit/6e95870e6e21915a51d5c1c327874a8b725b46b8))
* **logging:** add BBLogger for structured logging via swift-log ([ab19637](https://github.com/desaianand1/BatteryBoi-Recharged/commit/ab1963700dd07320cf2f3571ce44de1d9adb19ab))
* **project-rename:** renamed project to BatteryBoi - Recharged ([38203a2](https://github.com/desaianand1/BatteryBoi-Recharged/commit/38203a24b05f71933f9bd1b069e07000074b3fd2))
* **sentry:** add crash reporting and performance monitoring ([774d2d0](https://github.com/desaianand1/BatteryBoi-Recharged/commit/774d2d0fdcd78a0aadfd92a604b5faceaa998fb8))

### Bug Fixes

* address code quality issues from audit ([35070e3](https://github.com/desaianand1/BatteryBoi-Recharged/commit/35070e33d4cb70338570235ed713d51de5b3a531)), closes [#available](https://github.com/desaianand1/BatteryBoi-Recharged/issues/available)
* **animation:** remove duplicate keyframe scheduling loop ([64ed0cf](https://github.com/desaianand1/BatteryBoi-Recharged/commit/64ed0cf854b5ca5d7f360a407892aa6e024bbaa8))
* **animation:** use cancellable Tasks for keyframe animations ([c62e326](https://github.com/desaianand1/BatteryBoi-Recharged/commit/c62e3266bb9bc6cf763dcb7bd38241199e94c899)), closes [#35](https://github.com/desaianand1/BatteryBoi-Recharged/issues/35)
* **app:** add wake refresh cancellation and SFX error handling ([4e3fb49](https://github.com/desaianand1/BatteryBoi-Recharged/commit/4e3fb49a3064de82dd842fc4a1f08fd55a8bec05)), closes [#44](https://github.com/desaianand1/BatteryBoi-Recharged/issues/44) [#29](https://github.com/desaianand1/BatteryBoi-Recharged/issues/29)
* **battery:** correct thermal state detection logic ([d00e34c](https://github.com/desaianand1/BatteryBoi-Recharged/commit/d00e34c04727ade07a7c4695a4c31da6e9035612))
* **battery:** fix typo and add error handling ([c6ffc5b](https://github.com/desaianand1/BatteryBoi-Recharged/commit/c6ffc5b94a63763ca589644d5c0a2edbb86d3b4d))
* **battery:** guard against division by zero in depletion rate ([4c19431](https://github.com/desaianand1/BatteryBoi-Recharged/commit/4c194314d4c86bbf7eceb05d76363fe4a89aa4bc))
* **battery:** return nil for time remaining at 100% ([3d5dc8f](https://github.com/desaianand1/BatteryBoi-Recharged/commit/3d5dc8ff8568d7cab876b79e72b2fe65f99f8c8b))
* **battery:** serialize overlapping tasks in powerForceRefresh ([a4239ea](https://github.com/desaianand1/BatteryBoi-Recharged/commit/a4239eabdf88719271db1433e1e47eccf8c7bab8))
* **battery:** store and cancel fallback timer to prevent memory leak ([c11fcc5](https://github.com/desaianand1/BatteryBoi-Recharged/commit/c11fcc5bcfc73410b27900e7cf594bfd7e7ff91e))
* **battery:** store timer and migrate to async ProcessRunner ([dfd37ad](https://github.com/desaianand1/BatteryBoi-Recharged/commit/dfd37ad4a35e5825c26162e980c10d0081419eed))
* **bluetooth:** fix typos, CodingKey, and observer leak ([fc8a56b](https://github.com/desaianand1/BatteryBoi-Recharged/commit/fc8a56b747a8436fe580a169885f1876c23971d0))
* **bluetooth:** normalize address format and add Sentry capture ([d66ebbd](https://github.com/desaianand1/BatteryBoi-Recharged/commit/d66ebbd41b01601f0c42f0b152f4cc774e1bd63a))
* **bluetooth:** unregister device notification observers ([20dbe12](https://github.com/desaianand1/BatteryBoi-Recharged/commit/20dbe126c8d4f119580390598fbd1a5670dce6f6))
* **ci:** disable code signing for test builds ([e815af3](https://github.com/desaianand1/BatteryBoi-Recharged/commit/e815af3d1b0b09b7ef842f96530079f85005baaf))
* **ci:** remove trailing commas and use bundle exec for fastlane ([851d082](https://github.com/desaianand1/BatteryBoi-Recharged/commit/851d08210980defc32068b9225e5752ceee8b62c))
* **concurrency:** add explicit self in EventManager closures ([b434baf](https://github.com/desaianand1/BatteryBoi-Recharged/commit/b434bafc5cf69c08ca53b522d31b81b4e9ab3168))
* **concurrency:** add explicit self in WindowManager closures ([328010a](https://github.com/desaianand1/BatteryBoi-Recharged/commit/328010a69ac32ce854920823245e78edab8ff402))
* **concurrency:** change to minimal mode and fix trailing commas ([19946ef](https://github.com/desaianand1/BatteryBoi-Recharged/commit/19946ef246e6af67c4c0fc1f618ccfac811519cb))
* **concurrency:** remove invalid nonisolated(unsafe) from SMCKit enum ([8398b39](https://github.com/desaianand1/BatteryBoi-Recharged/commit/8398b3945488ea04e693be9b6ac21c38a4c7026a))
* **concurrency:** remove unnecessary await on nonisolated methods ([1da05b1](https://github.com/desaianand1/BatteryBoi-Recharged/commit/1da05b1e938624b4b89ea9c7f182809b1bdf6723))
* **concurrency:** resolve remaining Swift 6 concurrency errors in CI ([97cd56b](https://github.com/desaianand1/BatteryBoi-Recharged/commit/97cd56b26fd192f3a17e24d0893af963acb51df8))
* **concurrency:** resolve remaining Swift 6 concurrency errors in CI ([ec32508](https://github.com/desaianand1/BatteryBoi-Recharged/commit/ec325088d0fbfa828a9f4757c0c2298148b044fc))
* **concurrency:** set Swift strict concurrency to targeted ([684297f](https://github.com/desaianand1/BatteryBoi-Recharged/commit/684297f5c2eaf5510a57ba42d785e3b0210e5cb4))
* **concurrency:** wrap mach_task_self_ for Swift 6 safety ([e3f5f79](https://github.com/desaianand1/BatteryBoi-Recharged/commit/e3f5f799b46e7bddbce02d1fd5fcd792d8135ad5))
* **concurrency:** wrap main actor access in NavigationView ([48b2a99](https://github.com/desaianand1/BatteryBoi-Recharged/commit/48b2a99243ed5f7ecc73d83043331a0e2eaf028e))
* **constants:** update HUD dimensions to match actual values ([fb704c0](https://github.com/desaianand1/BatteryBoi-Recharged/commit/fb704c07993dc10ebc1a31427b96ce62e2079eec))
* **core:** add async ProcessRunner with timeout support ([1a43e91](https://github.com/desaianand1/BatteryBoi-Recharged/commit/1a43e91105b29a223b70425f2dab9acfe55bde2e))
* **fastlane:** configure provisioning profile for manual signing in CI ([971ae89](https://github.com/desaianand1/BatteryBoi-Recharged/commit/971ae8948699b72ee106443108cb256245e3ac89))
* **fastlane:** resolve code signing conflicts with match ([a026309](https://github.com/desaianand1/BatteryBoi-Recharged/commit/a026309d043f304aadb4b5c7ed8a410a5111db2a))
* **fastlane:** use correct parameter name for build_mac_app ([2f1f0d1](https://github.com/desaianand1/BatteryBoi-Recharged/commit/2f1f0d1ef4bb63931c423f519f52895417cc4088))
* **i18n:** correct Turkish percentage format specifier ([8bffeeb](https://github.com/desaianand1/BatteryBoi-Recharged/commit/8bffeeb708d96d054a16a0d9ccf023977b09f46c))
* **i18n:** standardize, fix and complete localization ([4a6723b](https://github.com/desaianand1/BatteryBoi-Recharged/commit/4a6723bb8520b44dda5bea79c6c9949b03c6a251))
* **memory:** fix IOObjectRelease leak and remove unused timer ([59f7696](https://github.com/desaianand1/BatteryBoi-Recharged/commit/59f7696dc0c46e723461e4f94bb8af20f51462a5))
* **memory:** fix NSEvent monitor and observer memory leaks ([dbfedb9](https://github.com/desaianand1/BatteryBoi-Recharged/commit/dbfedb9d0272790aafba4cec600f16dca6933750))
* **mocks:** update protocol and mocks to match current types ([dd90750](https://github.com/desaianand1/BatteryBoi-Recharged/commit/dd9075093479e468b69f7153187c04571e39eb3b))
* **process:** check exit code before returning output ([f043fb0](https://github.com/desaianand1/BatteryBoi-Recharged/commit/f043fb0f13657503b9bc6e007d5b47aff4e8d1b4))
* remove trailing commas in test function calls ([ec1305b](https://github.com/desaianand1/BatteryBoi-Recharged/commit/ec1305badab32f35c42d9f6d151dab329348ce70))
* **SMX:** removed dead SMC code since we migrated to Swift 6 IOKit ([e7eb0d4](https://github.com/desaianand1/BatteryBoi-Recharged/commit/e7eb0d42ccfac7b7d3bfd722b0c0ec6687de7168))
* **stats:** resolve Swift 6 CoreData concurrency violations ([d8bc413](https://github.com/desaianand1/BatteryBoi-Recharged/commit/d8bc413afb3abba90d8dcb0143928364cadc71e3))
* **stats:** use async context.perform for CoreData thread safety ([b0f0d51](https://github.com/desaianand1/BatteryBoi-Recharged/commit/b0f0d516d8b54ec88ce93aa1f0edd1322ae4b211))
* **test:** add nonisolated to mock service initializers ([e30a99d](https://github.com/desaianand1/BatteryBoi-Recharged/commit/e30a99d16716e026fa11a5314018dccfa939679e))
* **test:** remove MainActor from test setUp methods ([183e3ec](https://github.com/desaianand1/BatteryBoi-Recharged/commit/183e3ec1388f0da51e32762d7a3d85008f2ac9cf))
* **trigger:** replace fatalError with early return ([0c6547f](https://github.com/desaianand1/BatteryBoi-Recharged/commit/0c6547f50d88f012143c7304b800d7c9ba180430))
* **update:** add task cancellation to prevent state race ([9b286d7](https://github.com/desaianand1/BatteryBoi-Recharged/commit/9b286d78b33fb831c19659ba262b44d2ebfb5ef1))
* **update:** replace force unwrap with safe optional binding ([8d5b14f](https://github.com/desaianand1/BatteryBoi-Recharged/commit/8d5b14f0665d09e21f16cc5313f3ba29459be6a5))
* **window:** debounce charging state notifications ([ae14534](https://github.com/desaianand1/BatteryBoi-Recharged/commit/ae14534b3ce4841ba1eb9bf5c5fa69c455aaa777))
* **window:** fix memory leaks and Bluetooth threshold detection ([3f93ac3](https://github.com/desaianand1/BatteryBoi-Recharged/commit/3f93ac36df6535ae446c6a38fe445f0abd175e7b))
* **window:** fix state machine races and optimize polling ([2163b57](https://github.com/desaianand1/BatteryBoi-Recharged/commit/2163b57071249ec33046ed9fa1b8fdcd988747a2))
* **window:** support multi-monitor HUD positioning with fallback ([b004e76](https://github.com/desaianand1/BatteryBoi-Recharged/commit/b004e76e2c7d9913f84130e6dcee7325eefe0c31))
* **window:** use range-based battery threshold detection ([3a92abe](https://github.com/desaianand1/BatteryBoi-Recharged/commit/3a92abe639f36326ff05f9dcb543237097970ed6))

### Performance

* **ci:** optimize workflow speed without added complexity ([f587c2a](https://github.com/desaianand1/BatteryBoi-Recharged/commit/f587c2ade5201c4593f3951f5b40ec86de5fe3f2))

### Refactoring

* **app:** migrate blocking Process calls to async ProcessRunner ([4e4768c](https://github.com/desaianand1/BatteryBoi-Recharged/commit/4e4768cc24bbb838201cf6e72aa1eb5d3f2bc303))
* **arch:** update AppEnvironment to use protocol types ([316fbb6](https://github.com/desaianand1/BatteryBoi-Recharged/commit/316fbb61f1d56ce67819a98a18718891b242c641))
* **battery:** fix typo powerRemaing -> powerRemaining ([fb5f37b](https://github.com/desaianand1/BatteryBoi-Recharged/commit/fb5f37b5d2805cbb687866c38dea7076ce2e152b))
* **battery:** migrate to native IOKit APIs and fix race condition ([544ec0d](https://github.com/desaianand1/BatteryBoi-Recharged/commit/544ec0d1634f770c1c4459692ef46846f02e076a))
* **bluetooth:** replace Python scripts with native IOKit ([cd3ce27](https://github.com/desaianand1/BatteryBoi-Recharged/commit/cd3ce27ca82873a4daded41cc94a2f663e8d1a91)), closes [#55](https://github.com/desaianand1/BatteryBoi-Recharged/issues/55)
* **cleanup:** delete unused BBProfileScript.py ([6897d97](https://github.com/desaianand1/BatteryBoi-Recharged/commit/6897d97955172d880756a712eae4408b332e1a7b))
* **cleanup:** remove unused EventRecipients struct ([758ffb8](https://github.com/desaianand1/BatteryBoi-Recharged/commit/758ffb81106ea0987a0c24196329e7d62601f09e))
* **concurrency:** migrate Combine subscriptions to async/await ([564d4e6](https://github.com/desaianand1/BatteryBoi-Recharged/commit/564d4e632b5da93f72e4ed76dc06dc3bbf0d3991))
* **concurrency:** use nonisolated for Task properties ([2db883d](https://github.com/desaianand1/BatteryBoi-Recharged/commit/2db883d038da0baff1660654a177192a1409c7ce))
* **concurrency:** use Task.sleep in @MainActor classes ([ccde4ef](https://github.com/desaianand1/BatteryBoi-Recharged/commit/ccde4ef44ecbe6fab747e4547812060a5e238386))
* **core:** migrate from Combine to async/await concurrency model ([468db38](https://github.com/desaianand1/BatteryBoi-Recharged/commit/468db38751c90a7811f356b436b90b07548d3416))
* **logging:** replace print() with BBLogger ([0cbb378](https://github.com/desaianand1/BatteryBoi-Recharged/commit/0cbb37812b16b8252716bb584adb770568773465))
* **managers:** migrate all managers to @Observable @MainActor ([2dc788d](https://github.com/desaianand1/BatteryBoi-Recharged/commit/2dc788d7ac535a1a42de03ecffb7c2e89c51d419))
* **managers:** migrate subprocess calls to async ProcessRunner ([f752614](https://github.com/desaianand1/BatteryBoi-Recharged/commit/f752614da4e1c441de4e6c845d0bb42eb3b7955f))
* remove unused BBTriggerManager ([d60f376](https://github.com/desaianand1/BatteryBoi-Recharged/commit/d60f37651dc4c6c28d0953660407e842966f1903))
* replace deprecated API with modern alternatives ([ce16f28](https://github.com/desaianand1/BatteryBoi-Recharged/commit/ce16f28cc61e020495b93d866953af557b68ac4e))
* **swift6:** add nonisolated(unsafe) for Swift 6 compatibility ([000343d](https://github.com/desaianand1/BatteryBoi-Recharged/commit/000343daf86f0b68dcef9cbc7cdb8caafeb302a1))
* **test:** reorganize test structure and update project config ([a62a6f0](https://github.com/desaianand1/BatteryBoi-Recharged/commit/a62a6f016a3ad69f848a8823dc6832609b716f48))
* **ui:** centralize magic values into BBConstants and BBDesignTokens ([9525fde](https://github.com/desaianand1/BatteryBoi-Recharged/commit/9525fdec3722eb4ebe843d2332beae415adfe10e))
* **ui:** replace @EnvironmentObject with singleton pattern ([acfabb6](https://github.com/desaianand1/BatteryBoi-Recharged/commit/acfabb667ee62ffe0161c4ab8fa3d6c1de1bd215))
* update onChange to modern syntax ([e1a47c0](https://github.com/desaianand1/BatteryBoi-Recharged/commit/e1a47c09933f4ba3452d46fe419f657cc7824c0f))
* update remaining onChange to modern syntax ([a7e6539](https://github.com/desaianand1/BatteryBoi-Recharged/commit/a7e6539ecc5afb112c54a535714c7f8828292fff))
* **updates:** simplify UpdateManager and add version helpers ([7ffd214](https://github.com/desaianand1/BatteryBoi-Recharged/commit/7ffd2147e5c36468f3158b8a3e35309b8c4a5dd1))
* **views:** update onChange to Swift 5.9+ syntax ([8c6e590](https://github.com/desaianand1/BatteryBoi-Recharged/commit/8c6e5908d577805a530e3e3595f086fd1b7705c0))
