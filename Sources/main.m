#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#import <Security/Security.h>
#import <CoreFoundation/CFDictionary.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static NSString *const CAErrorDomain = @"CodexAuthMenu";
static NSString *const CADefaultPollIntervalKey = @"pollIntervalSeconds";
static NSString *const CAProxyModeKey = @"proxyMode";
static NSString *const CAProxyModeDirectValue = @"direct";
static NSString *const CAProxyModeSystemValue = @"system";
static NSString *const CAActiveThirdPartyAccountIDKey = @"activeThirdPartyAccountID";
static NSString *const CAOfficialConfigSnapshotKey = @"officialConfigSnapshot";
static NSString *const CANotificationDedupKey = @"notificationDedupByAccount";
static NSString *const CACliName = @"codex-auth";
static NSString *const CANodeName = @"node";
static NSString *const CAThirdPartyEndpointBaseURLValue = @"base_url";
static NSString *const CAThirdPartyEndpointFullURLValue = @"full_url";
static NSString *const CAThirdPartyAPIFormatResponsesValue = @"openai_responses";
static NSString *const CAThirdPartyAPIFormatChatValue = @"openai_chat";
static NSString *const CAKeychainService = @"CodexAuthMenu.ThirdPartyAPIKey";
static NSString *const CAAppSupportFolderName = @"CodexAuthMenu";
static NSString *const CAThirdPartyAccountsFileName = @"third-party-accounts.json";
static NSString *const CAOfficialAuthBackupFileName = @"official-auth.json.backup";
static NSString *const CACodexProviderIDPrefix = @"codex_auth_menu_";
static const NSTimeInterval CADefaultPollInterval = 300.0;
static const CGFloat CAMenuBarIconSize = 18.0;
static const CGFloat CASwitchAccountTabLocation = 320.0;
static const CGFloat CAAlignedMenuTabLocation = 230.0;

static const CGFloat CATagBgRedHigh = 0.92;
static const CGFloat CATagBgGreenHigh = 0.94;
static const CGFloat CATagBgBlueHigh = 0.93;
static const CGFloat CATagFgRedHigh = 0.28;
static const CGFloat CATagFgGreenHigh = 0.40;
static const CGFloat CATagFgBlueHigh = 0.33;
static const CGFloat CATagBgRedMedium = 0.95;
static const CGFloat CATagBgGreenMedium = 0.93;
static const CGFloat CATagBgBlueMedium = 0.88;
static const CGFloat CATagFgRedMedium = 0.51;
static const CGFloat CATagFgGreenMedium = 0.42;
static const CGFloat CATagFgBlueMedium = 0.18;
static const CGFloat CATagBgRedLow = 0.95;
static const CGFloat CATagBgGreenLow = 0.91;
static const CGFloat CATagBgBlueLow = 0.91;
static const CGFloat CATagFgRedLow = 0.56;
static const CGFloat CATagFgGreenLow = 0.25;
static const CGFloat CATagFgBlueLow = 0.25;
static const CGFloat CAPlanTagFgRed = 0.24;
static const CGFloat CAPlanTagFgGreen = 0.30;
static const CGFloat CAPlanTagFgBlue = 0.40;
static const CGFloat CAPlanTagBgRed = 0.90;
static const CGFloat CAPlanTagBgGreen = 0.92;
static const CGFloat CAPlanTagBgBlue = 0.96;

static const CGFloat CAErrorTagBgRed = 0.95;
static const CGFloat CAErrorTagBgGreen = 0.88;
static const CGFloat CAErrorTagBgBlue = 0.88;
static const CGFloat CAErrorTagFgRed = 0.65;
static const CGFloat CAErrorTagFgGreen = 0.15;
static const CGFloat CAErrorTagFgBlue = 0.15;

static const CGFloat CAThirdPartyTagFgRed = 0.10;
static const CGFloat CAThirdPartyTagFgGreen = 0.38;
static const CGFloat CAThirdPartyTagFgBlue = 0.18;
static const CGFloat CAThirdPartyTagBgRed = 0.86;
static const CGFloat CAThirdPartyTagBgGreen = 0.95;
static const CGFloat CAThirdPartyTagBgBlue = 0.88;

typedef NS_ENUM(NSInteger, CAAccountHealth) {
    CAAccountHealthOK = 0,
    CAAccountHealthAuthFailed = 1,
    CAAccountHealthForbidden = 2,
    CAAccountHealthRateLimited = 3,
    CAAccountHealthNetworkError = 4,
    CAAccountHealthUnknown = 5,
};

typedef NS_ENUM(NSInteger, CANotificationStatus) {
    CANotificationStatusNotDetermined = 0,
    CANotificationStatusEnabled = 1,
    CANotificationStatusDenied = 2,
};

typedef NS_ENUM(NSInteger, CAProxyMode) {
    CAProxyModeDirect = 0,
    CAProxyModeSystem = 1,
};

static BOOL CAIsNotificationsNotAllowedError(NSError *error) {
    return error != nil &&
           [error.domain isEqualToString:UNErrorDomain] &&
           error.code == UNErrorCodeNotificationsNotAllowed;
}

static NSString *CATrimString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return @"";
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *CAJSONStringValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *CATOMLEscapedString(NSString *value) {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    return escaped ?: @"";
}

static BOOL CAStringHasAnyPrefix(NSString *value, NSArray<NSString *> *prefixes) {
    for (NSString *prefix in prefixes) {
        if ([value hasPrefix:prefix]) return YES;
    }
    return NO;
}

@interface CAAccount : NSObject
@property(nonatomic, assign) BOOL active;
@property(nonatomic, assign) CAAccountHealth health;
@property(nonatomic, copy) NSString *index;
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSString *plan;
@property(nonatomic, copy) NSString *usage5h;
@property(nonatomic, copy) NSString *weeklyUsage;
@property(nonatomic, copy) NSString *lastActivity;
@property(nonatomic, copy) NSString *errorMessage;
@end

@implementation CAAccount
@end

@interface CAStatusSnapshot : NSObject
@property(nonatomic, copy) NSString *autoSwitch;
@property(nonatomic, copy) NSString *service;
@property(nonatomic, copy) NSString *thresholds;
@property(nonatomic, copy) NSString *usageMode;
@property(nonatomic, copy) NSString *accountMode;
@end

@implementation CAStatusSnapshot
- (instancetype)init {
    self = [super init];
    if (self) {
        _autoSwitch = @"-";
        _service = @"-";
        _thresholds = @"-";
        _usageMode = @"-";
        _accountMode = @"-";
    }
    return self;
}
@end

@interface CAThirdPartyAccount : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *remark;
@property(nonatomic, copy) NSString *providerName;
@property(nonatomic, copy) NSString *websiteURL;
@property(nonatomic, copy) NSString *endpointURL;
@property(nonatomic, copy) NSString *endpointType;
@property(nonatomic, copy) NSString *modelName;
@property(nonatomic, copy) NSString *apiFormat;
@property(nonatomic, copy) NSString *keychainIdentifier;
@property(nonatomic, copy) NSString *codexProviderID;
+ (instancetype)accountFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)isChatCompletionsOnly;
@end

@interface CAEditableTextField : NSTextField <NSTextFieldDelegate>
@property(nonatomic, weak) NSTextField *characterCountLabel;
- (void)updateCharacterCount;
@end

@implementation CAEditableTextField

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.delegate = self;
        self.usesSingleLineMode = YES;
        self.cell.scrollable = YES;
        self.cell.lineBreakMode = NSLineBreakByClipping;
    }
    return self;
}

- (void)setCharacterCountLabel:(NSTextField *)characterCountLabel {
    _characterCountLabel = characterCountLabel;
    [self updateCharacterCount];
}

- (void)updateCharacterCount {
    if (!self.characterCountLabel) return;
    self.characterCountLabel.stringValue =
        [NSString stringWithFormat:@"%lu characters, no length limit", (unsigned long)self.stringValue.length];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateCharacterCount];
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if ((event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) != NSEventModifierFlagCommand) {
        return [super performKeyEquivalent:event];
    }

    NSString *characters = [event.charactersIgnoringModifiers lowercaseString];
    SEL action = NULL;
    if ([characters isEqualToString:@"x"]) action = @selector(cut:);
    else if ([characters isEqualToString:@"c"]) action = @selector(copy:);
    else if ([characters isEqualToString:@"v"]) action = @selector(paste:);
    else if ([characters isEqualToString:@"a"]) action = @selector(selectAll:);
    if (!action) return [super performKeyEquivalent:event];

    id editor = [self currentEditor];
    if (editor && [editor respondsToSelector:action]) {
        [NSApp sendAction:action to:editor from:self];
        [self updateCharacterCount];
        return YES;
    }
    return [super performKeyEquivalent:event];
}

@end

@interface CASecureEditableTextField : NSSecureTextField <NSTextFieldDelegate>
@property(nonatomic, weak) NSTextField *characterCountLabel;
- (void)updateCharacterCount;
@end

@implementation CASecureEditableTextField

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.delegate = self;
        self.usesSingleLineMode = YES;
        self.cell.scrollable = YES;
        self.cell.lineBreakMode = NSLineBreakByClipping;
    }
    return self;
}

- (void)setCharacterCountLabel:(NSTextField *)characterCountLabel {
    _characterCountLabel = characterCountLabel;
    [self updateCharacterCount];
}

- (void)updateCharacterCount {
    if (!self.characterCountLabel) return;
    self.characterCountLabel.stringValue =
        [NSString stringWithFormat:@"%lu characters, no length limit", (unsigned long)self.stringValue.length];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateCharacterCount];
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if ((event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) != NSEventModifierFlagCommand) {
        return [super performKeyEquivalent:event];
    }

    NSString *characters = [event.charactersIgnoringModifiers lowercaseString];
    SEL action = NULL;
    if ([characters isEqualToString:@"x"]) action = @selector(cut:);
    else if ([characters isEqualToString:@"c"]) action = @selector(copy:);
    else if ([characters isEqualToString:@"v"]) action = @selector(paste:);
    else if ([characters isEqualToString:@"a"]) action = @selector(selectAll:);
    if (!action) return [super performKeyEquivalent:event];

    id editor = [self currentEditor];
    if (editor && [editor respondsToSelector:action]) {
        [NSApp sendAction:action to:editor from:self];
        [self updateCharacterCount];
        return YES;
    }
    return [super performKeyEquivalent:event];
}

@end

@implementation CAThirdPartyAccount

+ (instancetype)accountFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    CAThirdPartyAccount *account = [[CAThirdPartyAccount alloc] init];
    account.identifier = CATrimString(CAJSONStringValue(dictionary[@"id"]));
    account.remark = CATrimString(CAJSONStringValue(dictionary[@"remark"]));
    account.providerName = CATrimString(CAJSONStringValue(dictionary[@"providerName"]));
    account.websiteURL = CATrimString(CAJSONStringValue(dictionary[@"websiteURL"]));
    account.endpointURL = CATrimString(CAJSONStringValue(dictionary[@"endpointURL"]));
    account.endpointType = CATrimString(CAJSONStringValue(dictionary[@"endpointType"]));
    account.modelName = CATrimString(CAJSONStringValue(dictionary[@"modelName"]));
    account.apiFormat = CATrimString(CAJSONStringValue(dictionary[@"apiFormat"]));
    account.keychainIdentifier = CATrimString(CAJSONStringValue(dictionary[@"keychainIdentifier"]));
    account.codexProviderID = CATrimString(CAJSONStringValue(dictionary[@"codexProviderID"]));
    if (account.identifier.length == 0 ||
        account.remark.length == 0 ||
        account.providerName.length == 0 ||
        account.endpointURL.length == 0 ||
        account.endpointType.length == 0 ||
        account.modelName.length == 0 ||
        account.keychainIdentifier.length == 0 ||
        account.codexProviderID.length == 0) {
        return nil;
    }
    if (account.apiFormat.length == 0) account.apiFormat = CAThirdPartyAPIFormatResponsesValue;
    return account;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"id": self.identifier ?: @"",
        @"remark": self.remark ?: @"",
        @"providerName": self.providerName ?: @"",
        @"websiteURL": self.websiteURL ?: @"",
        @"endpointURL": self.endpointURL ?: @"",
        @"endpointType": self.endpointType ?: CAThirdPartyEndpointBaseURLValue,
        @"modelName": self.modelName ?: @"",
        @"apiFormat": self.apiFormat ?: CAThirdPartyAPIFormatResponsesValue,
        @"keychainIdentifier": self.keychainIdentifier ?: @"",
        @"codexProviderID": self.codexProviderID ?: @""
    };
}

- (BOOL)isChatCompletionsOnly {
    return [self.apiFormat isEqualToString:CAThirdPartyAPIFormatChatValue];
}

@end

@interface CAThirdPartyAccountStore : NSObject
+ (NSString *)applicationSupportDirectory;
+ (NSString *)accountsPath;
+ (NSArray<CAThirdPartyAccount *> *)loadAccounts:(NSError **)error;
+ (BOOL)saveAccounts:(NSArray<CAThirdPartyAccount *> *)accounts error:(NSError **)error;
+ (NSString *)apiKeyForAccount:(CAThirdPartyAccount *)account error:(NSError **)error;
+ (BOOL)saveAPIKey:(NSString *)apiKey forAccount:(CAThirdPartyAccount *)account error:(NSError **)error;
+ (BOOL)deleteAPIKeyForAccount:(CAThirdPartyAccount *)account error:(NSError **)error;
@end

@implementation CAThirdPartyAccountStore

+ (NSString *)applicationSupportDirectory {
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                    inDomains:NSUserDomainMask];
    NSURL *baseURL = urls.firstObject;
    if (!baseURL) {
        baseURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"]];
    }
    return [[baseURL path] stringByAppendingPathComponent:CAAppSupportFolderName];
}

+ (NSString *)accountsPath {
    return [[self applicationSupportDirectory] stringByAppendingPathComponent:CAThirdPartyAccountsFileName];
}

+ (NSArray<CAThirdPartyAccount *> *)loadAccounts:(NSError **)error {
    NSString *path = [self accountsPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return @[];

    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:30
                                     userInfo:@{NSLocalizedDescriptionKey: @"Third Party accounts file is not a JSON array."}];
        }
        return nil;
    }

    NSMutableArray<CAThirdPartyAccount *> *accounts = [NSMutableArray array];
    for (id item in (NSArray *)json) {
        CAThirdPartyAccount *account = [CAThirdPartyAccount accountFromDictionary:item];
        if (account) [accounts addObject:account];
    }
    return accounts;
}

+ (BOOL)saveAccounts:(NSArray<CAThirdPartyAccount *> *)accounts error:(NSError **)error {
    NSString *directory = [self applicationSupportDirectory];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:error]) {
        return NO;
    }

    NSMutableArray *json = [NSMutableArray array];
    for (CAThirdPartyAccount *account in accounts) {
        [json addObject:[account dictionaryRepresentation]];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    return [data writeToFile:[self accountsPath] options:NSDataWritingAtomic error:error];
}

+ (NSDictionary *)keychainQueryForIdentifier:(NSString *)identifier {
    return @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: CAKeychainService,
        (__bridge id)kSecAttrAccount: identifier ?: @""
    };
}

+ (NSString *)apiKeyForAccount:(CAThirdPartyAccount *)account error:(NSError **)error {
    NSMutableDictionary *query = [[self keychainQueryForIdentifier:account.keychainIdentifier] mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return @"";
    if (status != errSecSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:31
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Failed to read API Key from Keychain (%d).", (int)status]}];
        }
        return nil;
    }

    NSData *data = (__bridge_transfer NSData *)result;
    NSString *apiKey = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return apiKey ?: @"";
}

+ (BOOL)saveAPIKey:(NSString *)apiKey forAccount:(CAThirdPartyAccount *)account error:(NSError **)error {
    NSData *data = [apiKey dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    NSDictionary *query = [self keychainQueryForIdentifier:account.keychainIdentifier];
    NSDictionary *attributes = @{(__bridge id)kSecValueData: data};

    OSStatus updateStatus = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (updateStatus != errSecSuccess && updateStatus != errSecItemNotFound) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:32
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Failed to update API Key in Keychain (%d).", (int)updateStatus]}];
        }
        return NO;
    }

    if (updateStatus == errSecItemNotFound) {
        NSMutableDictionary *addQuery = [query mutableCopy];
        addQuery[(__bridge id)kSecValueData] = data;
        OSStatus addStatus = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
        if (addStatus != errSecSuccess) {
            if (error) {
                *error = [NSError errorWithDomain:CAErrorDomain
                                             code:33
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Failed to save API Key to Keychain (%d).", (int)addStatus]}];
            }
            return NO;
        }
    }

    NSError *readError = nil;
    NSString *savedAPIKey = [self apiKeyForAccount:account error:&readError];
    if (!savedAPIKey || ![savedAPIKey isEqualToString:apiKey]) {
        if (error) {
            *error = readError ?: [NSError errorWithDomain:CAErrorDomain
                                                       code:34
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                  @"API Key verification failed after saving. The saved value did not match the complete input."}];
        }
        return NO;
    }
    return YES;
}

+ (BOOL)deleteAPIKeyForAccount:(CAThirdPartyAccount *)account error:(NSError **)error {
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)[self keychainQueryForIdentifier:account.keychainIdentifier]);
    if (status == errSecSuccess || status == errSecItemNotFound) return YES;
    if (error) {
        *error = [NSError errorWithDomain:CAErrorDomain
                                     code:34
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                [NSString stringWithFormat:@"Failed to delete API Key from Keychain (%d).", (int)status]}];
    }
    return NO;
}

@end

@interface CACodexConfigManager : NSObject
+ (NSString *)codexConfigPath;
+ (NSString *)codexAuthPath;
+ (NSString *)readConfigText:(NSError **)error;
+ (BOOL)writeConfigText:(NSString *)text error:(NSError **)error;
+ (BOOL)backupOfficialAuthReplacingExisting:(BOOL)replaceExisting error:(NSError **)error;
+ (BOOL)writeThirdPartyConfigText:(NSString *)configText apiKey:(NSString *)apiKey error:(NSError **)error;
+ (BOOL)restoreOfficialAuthIfNeeded:(NSError **)error;
+ (NSDictionary *)snapshotFromConfigText:(NSString *)text;
+ (NSString *)configTextByApplyingThirdPartyAccount:(CAThirdPartyAccount *)account
                                            apiKey:(NSString *)apiKey
                                            toText:(NSString *)text
                                             error:(NSError **)error;
+ (NSString *)configTextByRestoringSnapshot:(NSDictionary *)snapshot
                        removingProviderIDs:(NSArray<NSString *> *)providerIDs
                                   fromText:(NSString *)text;
@end

@implementation CACodexConfigManager

+ (NSString *)codexConfigPath {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@".codex"] stringByAppendingPathComponent:@"config.toml"];
}

+ (NSString *)codexAuthPath {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@".codex"] stringByAppendingPathComponent:@"auth.json"];
}

+ (NSString *)officialAuthBackupPath {
    return [[CAThirdPartyAccountStore applicationSupportDirectory] stringByAppendingPathComponent:CAOfficialAuthBackupFileName];
}

+ (BOOL)ensurePrivateDirectory:(NSString *)directory error:(NSError **)error {
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                   withIntermediateDirectories:YES
                                                    attributes:@{NSFilePosixPermissions: @0700}
                                                         error:error]) {
        return NO;
    }
    chmod(directory.fileSystemRepresentation, 0700);
    return YES;
}

+ (BOOL)writePrivateData:(NSData *)data toPath:(NSString *)path error:(NSError **)error {
    if (![self ensurePrivateDirectory:[path stringByDeletingLastPathComponent] error:error]) return NO;
    if (![data writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
    chmod(path.fileSystemRepresentation, 0600);
    return YES;
}

+ (BOOL)backupOfficialAuthReplacingExisting:(BOOL)replaceExisting error:(NSError **)error {
    NSString *backupPath = [self officialAuthBackupPath];
    if (replaceExisting && [[NSFileManager defaultManager] fileExistsAtPath:backupPath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:backupPath error:error]) return NO;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:backupPath]) return YES;

    NSString *authPath = [self codexAuthPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:authPath]) {
        return [self writePrivateData:[NSData data] toPath:backupPath error:error];
    }
    NSData *data = [NSData dataWithContentsOfFile:authPath options:0 error:error];
    if (!data) return NO;
    return [self writePrivateData:data toPath:backupPath error:error];
}

+ (NSData *)thirdPartyAuthDataWithAPIKey:(NSString *)apiKey error:(NSError **)error {
    if (apiKey.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:44
                                     userInfo:@{NSLocalizedDescriptionKey: @"API Key is required."}];
        }
        return nil;
    }
    return [NSJSONSerialization dataWithJSONObject:@{@"OPENAI_API_KEY": apiKey}
                                           options:NSJSONWritingPrettyPrinted
                                             error:error];
}

+ (BOOL)restoreFileAtPath:(NSString *)path
                existed:(BOOL)existed
                   data:(NSData *)data
                  error:(NSError **)error {
    if (existed) {
        return [self writePrivateData:data ?: [NSData data] toPath:path error:error];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

+ (BOOL)writeThirdPartyConfigText:(NSString *)configText apiKey:(NSString *)apiKey error:(NSError **)error {
    NSString *authPath = [self codexAuthPath];
    BOOL authExisted = [[NSFileManager defaultManager] fileExistsAtPath:authPath];
    NSData *originalAuthData = authExisted ? [NSData dataWithContentsOfFile:authPath options:0 error:error] : nil;
    if (authExisted && !originalAuthData) return NO;

    NSData *thirdPartyAuthData = [self thirdPartyAuthDataWithAPIKey:apiKey error:error];
    if (!thirdPartyAuthData) return NO;
    if (![self writePrivateData:thirdPartyAuthData toPath:authPath error:error]) return NO;

    NSError *configError = nil;
    if ([self writeConfigText:configText error:&configError]) return YES;

    NSError *rollbackError = nil;
    BOOL rolledBack = [self restoreFileAtPath:authPath
                                      existed:authExisted
                                         data:originalAuthData
                                        error:&rollbackError];
    if (error) {
        NSString *message = configError.localizedDescription ?: @"Failed to write Codex config.";
        if (!rolledBack) {
            message = [message stringByAppendingFormat:@" API Key auth rollback also failed: %@",
                                                    rollbackError.localizedDescription ?: @"unknown error"];
        }
        *error = [NSError errorWithDomain:CAErrorDomain
                                     code:45
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
    return NO;
}

+ (BOOL)restoreOfficialAuthIfNeeded:(NSError **)error {
    NSString *backupPath = [self officialAuthBackupPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:backupPath]) return YES;

    NSData *data = [NSData dataWithContentsOfFile:backupPath options:0 error:error];
    if (!data) return NO;
    NSString *authPath = [self codexAuthPath];
    BOOL success = YES;
    if (data.length == 0) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:authPath]) {
            success = [[NSFileManager defaultManager] removeItemAtPath:authPath error:error];
        }
    } else {
        success = [self writePrivateData:data toPath:authPath error:error];
    }
    if (!success) return NO;
    [[NSFileManager defaultManager] removeItemAtPath:backupPath error:nil];
    return YES;
}

+ (NSString *)readConfigText:(NSError **)error {
    NSString *path = [self codexConfigPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return @"";
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    return text ?: nil;
}

+ (BOOL)writeConfigText:(NSString *)text error:(NSError **)error {
    NSString *path = [self codexConfigPath];
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:error]) {
        return NO;
    }
    return [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

+ (BOOL)line:(NSString *)trimmed startsWithTopLevelKey:(NSString *)key {
    if (![trimmed hasPrefix:key]) return NO;
    if (trimmed.length == key.length) return NO;
    unichar ch = [trimmed characterAtIndex:key.length];
    return ch == '=' || [[NSCharacterSet whitespaceCharacterSet] characterIsMember:ch];
}

+ (NSString *)topLevelRawValueForKey:(NSString *)key inText:(NSString *)text {
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trimmed = CATrimString(line);
        if ([trimmed hasPrefix:@"["]) break;
        if (![self line:trimmed startsWithTopLevelKey:key]) continue;
        NSRange eq = [trimmed rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        return CATrimString([trimmed substringFromIndex:eq.location + 1]);
    }
    return nil;
}

+ (NSDictionary *)snapshotFromConfigText:(NSString *)text {
    NSArray<NSString *> *keys = @[@"model_provider", @"model", @"model_reasoning_effort", @"disable_response_storage"];
    NSMutableDictionary *topLevel = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        NSString *rawValue = [self topLevelRawValueForKey:key inText:text];
        topLevel[key] = @{
            @"present": @(rawValue != nil),
            @"rawValue": rawValue ?: @""
        };
    }
    return @{
        @"topLevel": topLevel,
        @"createdAt": @([[NSDate date] timeIntervalSince1970])
    };
}

+ (NSString *)textByRemovingTopLevelKeys:(NSArray<NSString *> *)keys fromText:(NSString *)text {
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    BOOL inSection = NO;
    for (NSString *line in lines) {
        NSString *trimmed = CATrimString(line);
        if ([trimmed hasPrefix:@"["]) inSection = YES;
        BOOL remove = NO;
        if (!inSection) {
            for (NSString *key in keys) {
                if ([self line:trimmed startsWithTopLevelKey:key]) {
                    remove = YES;
                    break;
                }
            }
        }
        if (!remove) [kept addObject:line];
    }
    return [kept componentsJoinedByString:@"\n"];
}

+ (NSString *)textByRemovingProviderSections:(NSArray<NSString *> *)providerIDs fromText:(NSString *)text {
    if (text.length == 0) return text ?: @"";
    NSMutableSet<NSString *> *headers = [NSMutableSet set];
    for (NSString *providerID in providerIDs) {
        if (providerID.length > 0) {
            [headers addObject:[NSString stringWithFormat:@"[model_providers.%@]", providerID]];
        }
    }

    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    BOOL skipping = NO;
    for (NSString *line in lines) {
        NSString *trimmed = CATrimString(line);
        if ([trimmed hasPrefix:@"["]) {
            BOOL isManagedProviderSection =
                [trimmed hasPrefix:[NSString stringWithFormat:@"[model_providers.%@", CACodexProviderIDPrefix]] &&
                [trimmed hasSuffix:@"]"];
            skipping = [headers containsObject:trimmed] || isManagedProviderSection;
            if (skipping) continue;
        }
        if (!skipping) [kept addObject:line];
    }
    return [kept componentsJoinedByString:@"\n"];
}

+ (NSString *)normalizedBaseURLForAccount:(CAThirdPartyAccount *)account error:(NSError **)error {
    NSString *endpoint = [account.endpointURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([endpoint hasSuffix:@"/"]) {
        endpoint = [endpoint substringToIndex:endpoint.length - 1];
    }
    if (endpoint.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:40
                                     userInfo:@{NSLocalizedDescriptionKey: @"API Request URL is required."}];
        }
        return nil;
    }

    if (![account.endpointType isEqualToString:CAThirdPartyEndpointFullURLValue]) {
        return endpoint;
    }

    NSString *withoutQuery = [[endpoint componentsSeparatedByString:@"?"] firstObject];
    NSString *lower = [withoutQuery lowercaseString];
    if ([lower hasSuffix:@"/v1/responses"]) {
        return [withoutQuery substringToIndex:withoutQuery.length - @"/responses".length];
    }
    if ([lower hasSuffix:@"/responses"]) {
        return [withoutQuery substringToIndex:withoutQuery.length - @"/responses".length];
    }

    if (error) {
        *error = [NSError errorWithDomain:CAErrorDomain
                                     code:41
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"Full URL must end with /responses or /v1/responses for direct Codex use."}];
    }
    return nil;
}

+ (NSString *)configTextByApplyingThirdPartyAccount:(CAThirdPartyAccount *)account
                                            apiKey:(NSString *)apiKey
                                            toText:(NSString *)text
                                             error:(NSError **)error {
    if ([account isChatCompletionsOnly]) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:42
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"This provider uses Chat Completions. Local routing is required and is not supported yet."}];
        }
        return nil;
    }

    NSString *baseURL = [self normalizedBaseURLForAccount:account error:error];
    if (!baseURL) return nil;
    if (apiKey.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:43
                                     userInfo:@{NSLocalizedDescriptionKey: @"API Key is required."}];
        }
        return nil;
    }

    NSArray<NSString *> *topKeys = @[@"model_provider", @"model", @"model_reasoning_effort", @"disable_response_storage"];
    NSString *cleaned = [self textByRemovingTopLevelKeys:topKeys fromText:text ?: @""];
    cleaned = [self textByRemovingProviderSections:@[account.codexProviderID] fromText:cleaned];
    NSString *trimmedCleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSString *topBlock = [NSString stringWithFormat:
                          @"model_provider = \"%@\"\n"
                          "model = \"%@\"\n"
                          "model_reasoning_effort = \"high\"\n"
                          "disable_response_storage = true",
                          CATOMLEscapedString(account.codexProviderID),
                          CATOMLEscapedString(account.modelName)];
    NSString *providerBlock = [NSString stringWithFormat:
                               @"[model_providers.%@]\n"
                               "name = \"%@\"\n"
                               "base_url = \"%@\"\n"
                               "wire_api = \"responses\"\n"
                               "requires_openai_auth = true",
                               account.codexProviderID,
                               CATOMLEscapedString(account.providerName),
                               CATOMLEscapedString(baseURL)];

    NSMutableString *result = [NSMutableString stringWithString:topBlock];
    if (trimmedCleaned.length > 0) {
        [result appendFormat:@"\n\n%@", trimmedCleaned];
    }
    [result appendFormat:@"\n\n%@\n", providerBlock];
    return result;
}

+ (NSString *)configTextByRestoringSnapshot:(NSDictionary *)snapshot
                        removingProviderIDs:(NSArray<NSString *> *)providerIDs
                                   fromText:(NSString *)text {
    NSArray<NSString *> *topKeys = @[@"model_provider", @"model", @"model_reasoning_effort", @"disable_response_storage"];
    NSString *cleaned = [self textByRemovingTopLevelKeys:topKeys fromText:text ?: @""];
    cleaned = [self textByRemovingProviderSections:providerIDs fromText:cleaned];
    NSString *trimmedCleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSDictionary *topLevel = [snapshot[@"topLevel"] isKindOfClass:[NSDictionary class]] ? snapshot[@"topLevel"] : @{};
    NSMutableArray<NSString *> *restoredLines = [NSMutableArray array];
    for (NSString *key in topKeys) {
        NSDictionary *entry = [topLevel[key] isKindOfClass:[NSDictionary class]] ? topLevel[key] : nil;
        if (![entry[@"present"] boolValue]) continue;
        NSString *rawValue = CAJSONStringValue(entry[@"rawValue"]);
        if (rawValue.length > 0) {
            [restoredLines addObject:[NSString stringWithFormat:@"%@ = %@", key, rawValue]];
        }
    }

    NSMutableString *result = [NSMutableString string];
    if (restoredLines.count > 0) {
        [result appendString:[restoredLines componentsJoinedByString:@"\n"]];
    }
    if (trimmedCleaned.length > 0) {
        if (result.length > 0) [result appendString:@"\n\n"];
        [result appendString:trimmedCleaned];
    }
    if (result.length > 0 && ![result hasSuffix:@"\n"]) [result appendString:@"\n"];
    return result;
}

@end

@interface CodexAuthManager : NSObject
@property(nonatomic, copy, readonly) NSString *binaryPath;
@property(nonatomic, copy, readonly) NSString *nodePath;
- (instancetype)initWithBinaryPath:(NSString *)binaryPath nodePath:(NSString *)nodePath;
- (BOOL)validateBinary:(NSError **)error;
- (NSDictionary *)fetchSnapshot:(NSError **)error;
- (BOOL)switchAccount:(NSString *)account error:(NSError **)error;
- (BOOL)setAutoSwitchEnabled:(BOOL)enabled error:(NSError **)error;
- (BOOL)openInTerminal:(NSError **)error;
- (BOOL)startLoginInTerminal:(NSError **)error;
+ (NSString *)resolvePathForCommand:(NSString *)command;
@end

@implementation CodexAuthManager

+ (NSString *)resolvePathForCommand:(NSString *)command {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/zsh";
    task.arguments = @[ @"-l", @"-c", [NSString stringWithFormat:@"command -v %@", command] ];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];
    NSError *launchError = nil;
    [task launchAndReturnError:&launchError];
    if (launchError) return nil;
    [task waitUntilExit];
    if (task.terminationStatus != 0) return nil;
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (path.length == 0) return nil;
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || isDir) return nil;
    return path;
}

- (NSString *)nodePathForBinary:(NSString *)binaryPath {
    NSString *nodeDir = [binaryPath stringByDeletingLastPathComponent];
    NSString *candidateNode = [nodeDir stringByAppendingPathComponent:@"node"];
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:candidateNode isDirectory:&isDir] && !isDir) {
        return candidateNode;
    }
    return nil;
}

- (instancetype)initWithBinaryPath:(NSString *)binaryPath nodePath:(NSString *)nodePath {
    self = [super init];
    if (self) {
        _binaryPath = binaryPath ?: [CodexAuthManager resolvePathForCommand:CACliName];
        if (nodePath) {
            _nodePath = nodePath;
        } else if (_binaryPath) {
            NSString *siblingNode = [self nodePathForBinary:_binaryPath];
            _nodePath = siblingNode ?: [CodexAuthManager resolvePathForCommand:CANodeName];
        } else {
            _nodePath = [CodexAuthManager resolvePathForCommand:CANodeName];
        }
    }
    return self;
}

- (instancetype)init {
    return [self initWithBinaryPath:nil nodePath:nil];
}

- (BOOL)validateBinary:(NSError **)error {
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:self.binaryPath isDirectory:&isDirectory];
    if (!exists || isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:10
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"CLI not found at %@", self.binaryPath]}];
        }
        return NO;
    }

    if (![[NSFileManager defaultManager] isExecutableFileAtPath:self.binaryPath]) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:11
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"CLI is not executable: %@", self.binaryPath]}];
        }
        return NO;
    }

    BOOL nodeIsDirectory = NO;
    BOOL nodeExists = [[NSFileManager defaultManager] fileExistsAtPath:self.nodePath isDirectory:&nodeIsDirectory];
    if (!nodeExists || nodeIsDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:12
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Node not found at %@", self.nodePath]}];
        }
        return NO;
    }

    if (![[NSFileManager defaultManager] isExecutableFileAtPath:self.nodePath]) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:13
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Node is not executable: %@", self.nodePath]}];
        }
        return NO;
    }
    return YES;
}

- (NSDictionary *)fetchSnapshot:(NSError **)error {
    if (![self validateBinary:error]) return nil;

    NSString *statusOutput = [self run:@[@"status"] error:error];
    if (!statusOutput) return nil;
    NSString *listOutput = [self run:@[@"list"] error:error];
    if (!listOutput) return nil;

    CAStatusSnapshot *status = [self parseStatus:statusOutput];
    NSArray *accounts = [self parseAccounts:listOutput error:error];
    if (!accounts) return nil;
    return @{@"status": status, @"accounts": accounts};
}

- (BOOL)switchAccount:(NSString *)account error:(NSError **)error {
    return [self run:@[@"switch", account] error:error] != nil;
}

- (BOOL)setAutoSwitchEnabled:(BOOL)enabled error:(NSError **)error {
    return [self run:@[@"config", @"auto", enabled ? @"enable" : @"disable"] error:error] != nil;
}

- (NSString *)shellEscapedPath:(NSString *)path {
    return [NSString stringWithFormat:@"'%@'", [path stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}

- (BOOL)openInTerminal:(NSError **)error {
    NSString *escapedBinary = [self shellEscapedPath:self.binaryPath];
    NSString *script = [NSString stringWithFormat:
                        @"tell application \"Terminal\"\n"
                        "activate\n"
                        "do script \"%@ status; %@ list\"\n"
                        "end tell", escapedBinary, escapedBinary];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    NSDictionary *scriptError = nil;
    [appleScript executeAndReturnError:&scriptError];
    if (scriptError) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Failed to open Terminal: %@", scriptError]}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)startLoginInTerminal:(NSError **)error {
    NSString *escapedNode = [self shellEscapedPath:self.nodePath];
    NSString *escapedBinary = [self shellEscapedPath:self.binaryPath];
    NSString *script = [NSString stringWithFormat:
                        @"tell application \"Terminal\"\n"
                        "activate\n"
                        "do script \"%@ %@ login\"\n"
                        "end tell", escapedNode, escapedBinary];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    NSDictionary *scriptError = nil;
    [appleScript executeAndReturnError:&scriptError];
    if (scriptError) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:14
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Failed to start login in Terminal: %@", scriptError]}];
        }
        return NO;
    }
    return YES;
}

- (NSString *)proxyURLFromSettings:(NSDictionary *)settings
                         enableKey:(NSString *)enableKey
                           hostKey:(NSString *)hostKey
                           portKey:(NSString *)portKey {
    NSNumber *enabled = settings[enableKey];
    if (![enabled boolValue]) return nil;
    NSString *host = settings[hostKey];
    NSNumber *port = settings[portKey];
    if (!host || host.length == 0 || !port) return nil;
    return [NSString stringWithFormat:@"http://%@:%@", host, port];
}

- (NSDictionary<NSString *, NSString *> *)systemProxyURLs {
    NSDictionary *services = (__bridge_transfer NSDictionary *)CFNetworkCopySystemProxySettings();
    if (!services) return @{};

    NSMutableDictionary<NSString *, NSString *> *urls = [NSMutableDictionary dictionary];
    NSString *httpProxy = [self proxyURLFromSettings:services
                                          enableKey:@"HTTPEnable"
                                            hostKey:@"HTTPProxy"
                                            portKey:@"HTTPPort"];
    NSString *httpsProxy = [self proxyURLFromSettings:services
                                           enableKey:@"HTTPSEnable"
                                             hostKey:@"HTTPSProxy"
                                             portKey:@"HTTPSPort"];
    if (httpProxy.length > 0) urls[@"http"] = httpProxy;
    if (httpsProxy.length > 0) urls[@"https"] = httpsProxy;
    return urls;
}

- (CAProxyMode)loadProxyMode {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:CAProxyModeKey];
    if ([saved isEqualToString:CAProxyModeSystemValue]) return CAProxyModeSystem;
    return CAProxyModeDirect;
}

- (void)removeProxyEnvironment:(NSMutableDictionary *)env {
    for (NSString *key in @[@"HTTP_PROXY", @"HTTPS_PROXY", @"ALL_PROXY", @"http_proxy", @"https_proxy", @"all_proxy"]) {
        [env removeObjectForKey:key];
    }
}

- (void)configureProxyEnvironment:(NSMutableDictionary *)env {
    [self removeProxyEnvironment:env];
    if ([self loadProxyMode] != CAProxyModeSystem) return;

    NSDictionary<NSString *, NSString *> *proxyURLs = [self systemProxyURLs];
    NSString *httpProxy = proxyURLs[@"http"];
    NSString *httpsProxy = proxyURLs[@"https"] ?: httpProxy;
    NSString *allProxy = httpsProxy ?: httpProxy;

    if (httpProxy.length > 0) {
        env[@"HTTP_PROXY"] = httpProxy;
        env[@"http_proxy"] = httpProxy;
    }
    if (httpsProxy.length > 0) {
        env[@"HTTPS_PROXY"] = httpsProxy;
        env[@"https_proxy"] = httpsProxy;
    }
    if (allProxy.length > 0) {
        env[@"ALL_PROXY"] = allProxy;
        env[@"all_proxy"] = allProxy;
    }
}

- (NSString *)run:(NSArray<NSString *> *)arguments error:(NSError **)error {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/zsh";

    NSMutableArray<NSString *> *cmdParts = [NSMutableArray arrayWithObject:self.binaryPath];
    [cmdParts addObjectsFromArray:arguments];
    NSString *joinedCmd = [cmdParts componentsJoinedByString:@" "];
    task.arguments = @[ @"-l", @"-c", joinedCmd ];

    NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    [self configureProxyEnvironment:env];
    task.environment = env;

    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Failed to launch codex-auth."}];
        }
        return nil;
    }

    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
    NSData *mergedData = outputData.length > 0 ? outputData : errorData;
    NSString *text = [[NSString alloc] initWithData:mergedData encoding:NSUTF8StringEncoding];
    if (!text) {
        if (error) {
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"codex-auth returned undecodable output."}];
        }
        return nil;
    }

    if (task.terminationStatus != 0) {
        if (error) {
            NSString *message = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:task.terminationStatus
                                     userInfo:@{NSLocalizedDescriptionKey: message.length > 0 ? message : @"codex-auth failed."}];
        }
        return nil;
    }

    return text;
}

- (CAStatusSnapshot *)parseStatus:(NSString *)output {
    CAStatusSnapshot *snapshot = [[CAStatusSnapshot alloc] init];
    NSArray<NSString *> *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSRange separator = [line rangeOfString:@":"];
        if (separator.location == NSNotFound) continue;

        NSString *key = [[line substringToIndex:separator.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *value = [[line substringFromIndex:separator.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([key isEqualToString:@"auto-switch"]) snapshot.autoSwitch = value;
        else if ([key isEqualToString:@"service"]) snapshot.service = value;
        else if ([key isEqualToString:@"thresholds"]) snapshot.thresholds = value;
        else if ([key isEqualToString:@"usage"]) snapshot.usageMode = value;
        else if ([key isEqualToString:@"account"]) snapshot.accountMode = value;
    }
    return snapshot;
}

- (CAAccountHealth)healthFromUsageField:(NSString *)field message:(NSString **)outMessage {
    if (!field || field.length == 0) {
        if (outMessage) *outMessage = nil;
        return CAAccountHealthOK;
    }
    NSString *trimmed = [field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0 || [trimmed isEqualToString:@"-"]) {
        if (outMessage) *outMessage = nil;
        return CAAccountHealthOK;
    }
    if ([trimmed containsString:@"%"]) {
        if (outMessage) *outMessage = nil;
        return CAAccountHealthOK;
    }
    if ([trimmed isEqualToString:@"401"] || [trimmed containsString:@"401"]) {
        if (outMessage) *outMessage = @"登录失效，需重新登录";
        return CAAccountHealthAuthFailed;
    }
    if ([trimmed isEqualToString:@"403"] || [trimmed containsString:@"403"]) {
        if (outMessage) *outMessage = @"权限不足";
        return CAAccountHealthForbidden;
    }
    if ([trimmed isEqualToString:@"429"] || [trimmed containsString:@"429"]) {
        if (outMessage) *outMessage = @"请求限流";
        return CAAccountHealthRateLimited;
    }
    if ([trimmed isEqualToString:@"RequestFailed"] || [trimmed containsString:@"RequestFailed"]) {
        if (outMessage) *outMessage = @"网络错误，检查代理";
        return CAAccountHealthNetworkError;
    }
    if (outMessage) *outMessage = nil;
    return CAAccountHealthOK;
}

- (CAAccountHealth)worseHealth:(CAAccountHealth)a b:(CAAccountHealth)b {
    return a > b ? a : b;
}

- (NSArray<CAAccount *> *)parseAccounts:(NSString *)output error:(NSError **)error {
    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\*)?\\s*(\\d+)\\s+(.+?)\\s{2,}(\\S+)\\s{2,}(.+?)\\s{2,}(.+?)\\s{2,}(.+)$"
                                                                           options:0
                                                                             error:&regexError];
    if (!regex) {
        if (error) *error = regexError;
        return nil;
    }

    NSMutableArray<CAAccount *> *accounts = [NSMutableArray array];
    NSArray<NSString *> *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0 || [line containsString:@"ACCOUNT"] || [line hasPrefix:@"---"]) continue;

        NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!match) continue;

        NSString *(^capture)(NSInteger) = ^NSString *(NSInteger idx) {
            NSRange range = [match rangeAtIndex:idx];
            if (range.location == NSNotFound) return @"";
            return [line substringWithRange:range];
        };

        CAAccount *account = [[CAAccount alloc] init];
        account.active = [capture(1) length] > 0;
        account.index = capture(2);
        account.account = capture(3);
        account.plan = capture(4);
        account.usage5h = capture(5);
        account.weeklyUsage = capture(6);
        account.lastActivity = capture(7);

        NSString *msg5h = nil;
        NSString *msgW = nil;
        CAAccountHealth h5h = [self healthFromUsageField:account.usage5h message:&msg5h];
        CAAccountHealth hW = [self healthFromUsageField:account.weeklyUsage message:&msgW];
        account.health = [self worseHealth:h5h b:hW];
        account.errorMessage = h5h >= hW ? msg5h : msgW;
        if (account.health == CAAccountHealthOK) account.errorMessage = nil;

        [accounts addObject:account];
    }

    if (accounts.count == 0 && error) {
        *error = [NSError errorWithDomain:CAErrorDomain
                                     code:4
                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not parse any accounts from `codex-auth list`."}];
    }
    return accounts;
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) CodexAuthManager *manager;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) CAStatusSnapshot *status;
@property(nonatomic, copy) NSArray<CAAccount *> *accounts;
@property(nonatomic, strong) NSDate *lastUpdated;
@property(nonatomic, copy) NSString *lastError;
@property(nonatomic, assign) BOOL refreshing;
@property(nonatomic, assign) BOOL switching;
@property(nonatomic, assign) NSTimeInterval pollInterval;
@property(nonatomic, assign) CAProxyMode proxyMode;
@property(nonatomic, assign) CANotificationStatus notificationStatus;
@property(nonatomic, copy) NSArray<CAThirdPartyAccount *> *thirdPartyAccounts;
@property(nonatomic, copy) NSString *activeThirdPartyAccountID;
@end

@implementation AppDelegate

- (NSImage *)menuBarIconImage {
    NSImage *image = [NSImage imageNamed:@"MenuBarIcon"];
    if (!image) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"MenuBarIcon" ofType:@"png"];
        if (path) {
            image = [[NSImage alloc] initWithContentsOfFile:path];
        }
    }
    if (!image) return nil;

    image.size = NSMakeSize(CAMenuBarIconSize, CAMenuBarIconSize);
    image.template = NO;
    return image;
}

- (NSString *)menuBarUsageTitle {
    if ([self activeThirdPartyAccount]) {
        return @"API";
    }
    for (CAAccount *account in self.accounts) {
        if (account.active) {
            if (account.health != CAAccountHealthOK && account.health != CAAccountHealthUnknown) {
                switch (account.health) {
                    case CAAccountHealthAuthFailed: return @"⚠ 登录失效";
                    case CAAccountHealthForbidden: return @"⚠ 权限不足";
                    case CAAccountHealthRateLimited: return @"⚠ 限流";
                    case CAAccountHealthNetworkError: return @"⚠ 网络错误";
                    default: break;
                }
            }
            NSArray<NSString *> *parts = [account.usage5h componentsSeparatedByString:@" "];
            NSString *usage = parts.count > 0 ? parts[0] : account.usage5h;
            return usage;
        }
    }
    return @"--%";
}

- (void)updateStatusItemButton {
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) return;

    button.image = [self menuBarIconImage];
    button.imagePosition = NSImageLeft;
    button.title = [self menuBarUsageTitle];
}

- (CAThirdPartyAccount *)activeThirdPartyAccount {
    if (self.activeThirdPartyAccountID.length == 0) return nil;
    for (CAThirdPartyAccount *account in self.thirdPartyAccounts) {
        if ([account.identifier isEqualToString:self.activeThirdPartyAccountID]) {
            return account;
        }
    }
    return nil;
}

- (CAThirdPartyAccount *)thirdPartyAccountWithID:(NSString *)identifier {
    if (identifier.length == 0) return nil;
    for (CAThirdPartyAccount *account in self.thirdPartyAccounts) {
        if ([account.identifier isEqualToString:identifier]) return account;
    }
    return nil;
}

- (NSArray<NSString *> *)thirdPartyProviderIDs {
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (CAThirdPartyAccount *account in self.thirdPartyAccounts) {
        if (account.codexProviderID.length > 0) [ids addObject:account.codexProviderID];
    }
    return ids;
}

- (void)loadThirdPartyAccounts {
    NSError *error = nil;
    NSArray<CAThirdPartyAccount *> *accounts = [CAThirdPartyAccountStore loadAccounts:&error];
    if (accounts) {
        self.thirdPartyAccounts = accounts;
    } else {
        self.thirdPartyAccounts = @[];
        self.lastError = error.localizedDescription;
    }

    NSString *activeID = [[NSUserDefaults standardUserDefaults] stringForKey:CAActiveThirdPartyAccountIDKey];
    self.activeThirdPartyAccountID = [self thirdPartyAccountWithID:activeID] ? activeID : nil;
}

- (BOOL)saveThirdPartyAccounts:(NSError **)error {
    return [CAThirdPartyAccountStore saveAccounts:self.thirdPartyAccounts ?: @[] error:error];
}

- (void)setActiveThirdPartyAccountIDAndPersist:(NSString *)identifier {
    self.activeThirdPartyAccountID = identifier;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (identifier.length > 0) {
        [defaults setObject:identifier forKey:CAActiveThirdPartyAccountIDKey];
    } else {
        [defaults removeObjectForKey:CAActiveThirdPartyAccountIDKey];
    }
    [defaults synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.manager = [[CodexAuthManager alloc] init];
    self.status = [[CAStatusSnapshot alloc] init];
    self.accounts = @[];
    self.thirdPartyAccounts = @[];
    self.notificationStatus = CANotificationStatusNotDetermined;
    self.pollInterval = [self loadPollInterval];
    self.proxyMode = [self loadProxyMode];
    [self loadThirdPartyAccounts];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self updateStatusItemButton];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self rebuildMenu];
    [self refreshNotificationSettings];
    [self refresh];
    [self scheduleTimer];
}

- (void)refresh {
    if (self.refreshing) return;
    self.refreshing = YES;
    self.lastError = nil;
    [self rebuildMenu];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSDictionary *snapshot = [self.manager fetchSnapshot:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.refreshing = NO;
            if (snapshot) {
                self.status = snapshot[@"status"];
                self.accounts = snapshot[@"accounts"];
                self.lastUpdated = [NSDate date];
                [self notifyIfNeededForAccounts:self.accounts];
            } else {
                self.lastError = error.localizedDescription;
            }
            [self rebuildMenu];
        });
    });
}

- (void)toggleAutoSwitch:(id)sender {
    BOOL shouldEnable = ![[self.status.autoSwitch uppercaseString] isEqualToString:@"ON"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL success = [self.manager setAutoSwitchEnabled:shouldEnable error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) [self refresh];
            else {
                self.lastError = error.localizedDescription;
                [self rebuildMenu];
            }
        });
    });
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title ?: @"CodexAuthMenu";
    alert.informativeText = message ?: @"";
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert runModal];
}

- (BOOL)restoreOfficialCodexConfigIfNeeded:(NSError **)error {
    NSDictionary *snapshot = [[NSUserDefaults standardUserDefaults] dictionaryForKey:CAOfficialConfigSnapshotKey];
    NSString *originalConfigText = nil;
    BOOL configExisted = [[NSFileManager defaultManager] fileExistsAtPath:[CACodexConfigManager codexConfigPath]];
    if ([snapshot isKindOfClass:[NSDictionary class]]) {
        originalConfigText = [CACodexConfigManager readConfigText:error];
        if (!originalConfigText && error && *error) return NO;

        NSString *restored = [CACodexConfigManager configTextByRestoringSnapshot:snapshot
                                                             removingProviderIDs:[self thirdPartyProviderIDs]
                                                                        fromText:originalConfigText ?: @""];
        if (![CACodexConfigManager writeConfigText:restored error:error]) return NO;
    }

    NSError *authError = nil;
    if (![CACodexConfigManager restoreOfficialAuthIfNeeded:&authError]) {
        if ([snapshot isKindOfClass:[NSDictionary class]]) {
            NSError *rollbackError = nil;
            BOOL rolledBack = configExisted
                ? [CACodexConfigManager writeConfigText:originalConfigText ?: @"" error:&rollbackError]
                : [[NSFileManager defaultManager] removeItemAtPath:[CACodexConfigManager codexConfigPath]
                                                              error:&rollbackError];
            if (!rolledBack && error) {
                *error = [NSError errorWithDomain:CAErrorDomain
                                             code:46
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"%@ Config rollback also failed: %@",
                                                         authError.localizedDescription ?: @"Failed to restore official authentication.",
                                                         rollbackError.localizedDescription ?: @"unknown error"]}];
                return NO;
            }
        }
        if (error) *error = authError;
        return NO;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:CAOfficialConfigSnapshotKey];
    [defaults removeObjectForKey:CAActiveThirdPartyAccountIDKey];
    [defaults synchronize];
    return YES;
}

- (void)switchAccount:(NSMenuItem *)sender {
    if (self.switching) return;
    NSString *account = sender.representedObject;
    if (account.length == 0) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Confirm Account Switch";
    alert.informativeText = [NSString stringWithFormat:@"Switch the active Codex account to %@?", account];
    [alert addButtonWithTitle:@"Confirm Switch"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    self.switching = YES;
    self.lastError = nil;
    [self rebuildMenu];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL restoredOfficial = [self restoreOfficialCodexConfigIfNeeded:&error];
        BOOL success = restoredOfficial;
        if (restoredOfficial) {
            success = [self.manager switchAccount:account error:&error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.switching = NO;
            if (restoredOfficial) {
                self.activeThirdPartyAccountID = nil;
            }
            if (success) {
                [self refresh];
            }
            else {
                self.lastError = error.localizedDescription;
                [self rebuildMenu];
            }
        });
    });
}

- (void)switchThirdPartyAccount:(NSMenuItem *)sender {
    if (self.switching) return;
    NSString *identifier = sender.representedObject;
    CAThirdPartyAccount *account = [self thirdPartyAccountWithID:identifier];
    if (!account) return;

    if ([account isChatCompletionsOnly]) {
        [self showAlertWithTitle:@"Local Routing Required"
                         message:@"This provider uses Chat Completions. Local routing is required and is not supported yet. This version only enables Responses API compatible providers."];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Confirm Third Party Switch";
    alert.informativeText = [NSString stringWithFormat:@"Switch Codex to Third Party provider %@ (%@)?\n\nCurrent Codex sessions may need to be restarted.", account.providerName, account.remark];
    [alert addButtonWithTitle:@"Confirm Switch"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    self.switching = YES;
    self.lastError = nil;
    [self rebuildMenu];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSString *apiKey = [CAThirdPartyAccountStore apiKeyForAccount:account error:&error];
        BOOL success = apiKey != nil;
        if (success) {
            NSString *configText = [CACodexConfigManager readConfigText:&error];
            success = configText != nil;
            if (success) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                BOOL creatingOfficialSnapshot =
                    self.activeThirdPartyAccountID.length == 0 &&
                    ![defaults dictionaryForKey:CAOfficialConfigSnapshotKey];
                if (creatingOfficialSnapshot) {
                    [defaults setObject:[CACodexConfigManager snapshotFromConfigText:configText]
                                 forKey:CAOfficialConfigSnapshotKey];
                    [defaults synchronize];
                }

                success = [CACodexConfigManager backupOfficialAuthReplacingExisting:creatingOfficialSnapshot
                                                                                error:&error];
                NSString *updated = [CACodexConfigManager configTextByApplyingThirdPartyAccount:account
                                                                                         apiKey:apiKey
                                                                                         toText:configText
                                                                                          error:&error];
                success = success && updated != nil;
                if (success) {
                    success = [CACodexConfigManager writeThirdPartyConfigText:updated
                                                                       apiKey:apiKey
                                                                        error:&error];
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.switching = NO;
            if (success) {
                [self setActiveThirdPartyAccountIDAndPersist:account.identifier];
                self.lastError = nil;
                [self rebuildMenu];
                [self showAlertWithTitle:@"Third Party Enabled"
                                 message:@"Codex provider config has been updated. Restart existing Codex sessions to reload ~/.codex/config.toml."];
            } else {
                self.lastError = error.localizedDescription;
                [self rebuildMenu];
            }
        });
    });
}

- (void)openInTerminal:(id)sender {
    NSError *error = nil;
    if (![self.manager openInTerminal:&error]) {
        self.lastError = error.localizedDescription;
        [self rebuildMenu];
    }
}

- (NSString *)newThirdPartyIdentifier {
    NSString *uuid = [[[NSUUID UUID] UUIDString] lowercaseString];
    return [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

- (NSString *)codexProviderIDForIdentifier:(NSString *)identifier {
    NSString *suffix = identifier.length >= 12 ? [identifier substringToIndex:12] : identifier;
    return [CACodexProviderIDPrefix stringByAppendingString:suffix];
}

- (NSString *)inferAPIFormatForProviderName:(NSString *)providerName endpointURL:(NSString *)endpointURL {
    NSString *combined = [[NSString stringWithFormat:@"%@ %@", providerName ?: @"", endpointURL ?: @""] lowercaseString];
    if ([combined containsString:@"chat/completions"] ||
        [combined containsString:@"deepseek"] ||
        [combined containsString:@"kimi"] ||
        [combined containsString:@"moonshot"]) {
        return CAThirdPartyAPIFormatChatValue;
    }
    return CAThirdPartyAPIFormatResponsesValue;
}

- (NSTextField *)labelWithString:(NSString *)label frame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.stringValue = label ?: @"";
    field.editable = NO;
    field.bezeled = NO;
    field.drawsBackground = NO;
    field.alignment = NSTextAlignmentRight;
    return field;
}

- (NSTextField *)textFieldWithString:(NSString *)value frame:(NSRect)frame placeholder:(NSString *)placeholder {
    NSTextField *field = [[CAEditableTextField alloc] initWithFrame:frame];
    field.stringValue = value ?: @"";
    field.placeholderString = placeholder ?: @"";
    return field;
}

- (NSTextField *)secureTextFieldWithString:(NSString *)value frame:(NSRect)frame placeholder:(NSString *)placeholder {
    CASecureEditableTextField *field = [[CASecureEditableTextField alloc] initWithFrame:frame];
    field.stringValue = value ?: @"";
    field.placeholderString = placeholder ?: @"";
    return field;
}

- (BOOL)deleteThirdPartyAccount:(CAThirdPartyAccount *)account error:(NSError **)error {
    BOOL deletingActive = [self.activeThirdPartyAccountID isEqualToString:account.identifier];
    if (deletingActive && ![self restoreOfficialCodexConfigIfNeeded:error]) {
        return NO;
    }
    if (deletingActive) {
        [self setActiveThirdPartyAccountIDAndPersist:nil];
    }

    NSMutableArray<CAThirdPartyAccount *> *remaining = [NSMutableArray array];
    for (CAThirdPartyAccount *candidate in self.thirdPartyAccounts) {
        if (![candidate.identifier isEqualToString:account.identifier]) {
            [remaining addObject:candidate];
        }
    }
    if (![CAThirdPartyAccountStore saveAccounts:remaining error:error]) return NO;
    NSError *keyError = nil;
    if (![CAThirdPartyAccountStore deleteAPIKeyForAccount:account error:&keyError]) {
        NSError *rollbackError = nil;
        BOOL rolledBack = [CAThirdPartyAccountStore saveAccounts:self.thirdPartyAccounts error:&rollbackError];
        if (error) {
            NSString *message = keyError.localizedDescription ?: @"Failed to delete API Key.";
            if (!rolledBack) {
                message = [message stringByAppendingFormat:@" Account list rollback also failed: %@",
                                                        rollbackError.localizedDescription ?: @"unknown error"];
            }
            *error = [NSError errorWithDomain:CAErrorDomain
                                         code:35
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }
    self.thirdPartyAccounts = remaining;
    return YES;
}

- (BOOL)rewriteConfigForActiveThirdPartyAccount:(CAThirdPartyAccount *)account error:(NSError **)error {
    NSString *apiKey = [CAThirdPartyAccountStore apiKeyForAccount:account error:error];
    if (!apiKey) return NO;
    NSString *configText = [CACodexConfigManager readConfigText:error];
    if (!configText) return NO;
    NSString *updated = [CACodexConfigManager configTextByApplyingThirdPartyAccount:account
                                                                             apiKey:apiKey
                                                                             toText:configText
                                                                              error:error];
    if (!updated) return NO;
    return [CACodexConfigManager writeThirdPartyConfigText:updated apiKey:apiKey error:error];
}

- (void)showThirdPartyAccountFormForAccount:(CAThirdPartyAccount *)existingAccount {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = existingAccount ? @"Edit Third Party Account" : @"Add Third Party Account";
    alert.informativeText = @"Initial support is for OpenAI Responses API compatible providers. DeepSeek/Kimi-style Chat Completions providers require local routing and cannot be enabled yet.";
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    if (existingAccount) [alert addButtonWithTitle:@"Delete"];
    alert.alertStyle = NSAlertStyleInformational;

    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, 282)];
    CGFloat labelX = 0;
    CGFloat fieldX = 150;
    CGFloat width = 320;
    CGFloat y = 248;
    CGFloat row = 32;

    NSTextField *remarkField = [self textFieldWithString:existingAccount.remark frame:NSMakeRect(fieldX, y, width, 24) placeholder:@"my-deepseek-key"];
    [view addSubview:[self labelWithString:@"API Remark *" frame:NSMakeRect(labelX, y + 3, 140, 18)]];
    [view addSubview:remarkField];

    y -= row;
    NSTextField *providerField = [self textFieldWithString:existingAccount.providerName frame:NSMakeRect(fieldX, y, width, 24) placeholder:@"DeepSeek / GLM / Custom"];
    [view addSubview:[self labelWithString:@"Codex Provider Name *" frame:NSMakeRect(labelX, y + 3, 140, 18)]];
    [view addSubview:providerField];

    y -= row;
    NSTextField *websiteField = [self textFieldWithString:existingAccount.websiteURL frame:NSMakeRect(fieldX, y, width, 24) placeholder:@"https://example.com"];
    [view addSubview:[self labelWithString:@"Official Website" frame:NSMakeRect(labelX, y + 3, 140, 18)]];
    [view addSubview:websiteField];

    y -= row;
    NSString *apiKeyPlaceholder = existingAccount ? @"••••••••  Paste a new API Key to replace" : @"sk-...";
    CASecureEditableTextField *apiKeyField = (CASecureEditableTextField *)[self secureTextFieldWithString:@""
                                                                                                    frame:NSMakeRect(fieldX, y, width, 24)
                                                                                              placeholder:apiKeyPlaceholder];
    [view addSubview:[self labelWithString:@"API Key *" frame:NSMakeRect(labelX, y + 3, 140, 18)]];
    [view addSubview:apiKeyField];

    NSTextField *apiKeyCountLabel = [self labelWithString:@"" frame:NSMakeRect(fieldX, y - 17, width, 16)];
    apiKeyCountLabel.alignment = NSTextAlignmentLeft;
    apiKeyCountLabel.textColor = [NSColor secondaryLabelColor];
    apiKeyCountLabel.font = [NSFont systemFontOfSize:11];
    [view addSubview:apiKeyCountLabel];
    apiKeyField.characterCountLabel = apiKeyCountLabel;
    if (existingAccount) {
        apiKeyCountLabel.stringValue = @"Saved securely. Leave blank to keep it, or paste a new key.";
    }

    y -= 50;
    NSPopUpButton *endpointTypePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(fieldX, y, 180, 26) pullsDown:NO];
    [endpointTypePopup addItemWithTitle:@"Base URL"];
    [endpointTypePopup addItemWithTitle:@"Full URL"];
    if ([existingAccount.endpointType isEqualToString:CAThirdPartyEndpointFullURLValue]) {
        [endpointTypePopup selectItemWithTitle:@"Full URL"];
    }
    [view addSubview:[self labelWithString:@"Endpoint Type *" frame:NSMakeRect(labelX, y + 4, 140, 18)]];
    [view addSubview:endpointTypePopup];

    y -= row;
    NSTextField *endpointField = [self textFieldWithString:existingAccount.endpointURL frame:NSMakeRect(fieldX, y, width, 24) placeholder:@"https://api.example.com/v1"];
    [view addSubview:[self labelWithString:@"API Request URL *" frame:NSMakeRect(labelX, y + 3, 140, 18)]];
    [view addSubview:endpointField];

    y -= row;
    NSTextField *modelField = [self textFieldWithString:existingAccount.modelName frame:NSMakeRect(fieldX, y, width, 24) placeholder:@"gpt-5.5"];
    [view addSubview:[self labelWithString:@"Model Name *" frame:NSMakeRect(labelX, y + 3, 140, 18)]];
    [view addSubview:modelField];

    NSTextField *hint = [self labelWithString:@"Full URL must end with /responses or /v1/responses for direct Codex use."
                                        frame:NSMakeRect(0, 0, 470, 18)];
    hint.alignment = NSTextAlignmentLeft;
    hint.textColor = [NSColor secondaryLabelColor];
    [view addSubview:hint];

    alert.accessoryView = view;

    while (YES) {
        NSModalResponse response = [alert runModal];
        if (response == NSAlertSecondButtonReturn) return;

        if (existingAccount && response == NSAlertThirdButtonReturn) {
            NSAlert *confirm = [[NSAlert alloc] init];
            confirm.messageText = @"Delete Third Party Account";
            confirm.informativeText = [NSString stringWithFormat:@"Delete %@?", existingAccount.remark];
            [confirm addButtonWithTitle:@"Delete"];
            [confirm addButtonWithTitle:@"Cancel"];
            confirm.alertStyle = NSAlertStyleWarning;
            if ([confirm runModal] == NSAlertFirstButtonReturn) {
                NSError *deleteError = nil;
                if ([self deleteThirdPartyAccount:existingAccount error:&deleteError]) {
                    self.lastError = nil;
                } else {
                    self.lastError = deleteError.localizedDescription;
                }
                [self rebuildMenu];
            }
            return;
        }

        NSString *remark = CATrimString(remarkField.stringValue);
        NSString *providerName = CATrimString(providerField.stringValue);
        NSString *websiteURL = CATrimString(websiteField.stringValue);
        NSString *apiKey = CATrimString(apiKeyField.stringValue);
        NSString *endpointURL = CATrimString(endpointField.stringValue);
        NSString *modelName = CATrimString(modelField.stringValue);
        NSString *endpointType = [[endpointTypePopup titleOfSelectedItem] isEqualToString:@"Full URL"] ? CAThirdPartyEndpointFullURLValue : CAThirdPartyEndpointBaseURLValue;

        NSMutableArray<NSString *> *missing = [NSMutableArray array];
        if (remark.length == 0) [missing addObject:@"API Remark"];
        if (providerName.length == 0) [missing addObject:@"Codex Provider Name"];
        if (!existingAccount && apiKey.length == 0) [missing addObject:@"API Key"];
        if (endpointURL.length == 0) [missing addObject:@"API Request URL"];
        if (modelName.length == 0) [missing addObject:@"Model Name"];
        if (endpointType.length == 0) [missing addObject:@"Endpoint Type"];
        if (missing.count > 0) {
            [self showAlertWithTitle:@"Missing Required Fields"
                             message:[NSString stringWithFormat:@"Please fill: %@", [missing componentsJoinedByString:@", "]]];
            continue;
        }

        CAThirdPartyAccount *account = existingAccount
            ? [CAThirdPartyAccount accountFromDictionary:[existingAccount dictionaryRepresentation]]
            : [[CAThirdPartyAccount alloc] init];
        if (!existingAccount) {
            account.identifier = [self newThirdPartyIdentifier];
            account.keychainIdentifier = account.identifier;
            account.codexProviderID = [self codexProviderIDForIdentifier:account.identifier];
        }
        account.remark = remark;
        account.providerName = providerName;
        account.websiteURL = websiteURL;
        account.endpointURL = endpointURL;
        account.endpointType = endpointType;
        account.modelName = modelName;
        account.apiFormat = [self inferAPIFormatForProviderName:providerName endpointURL:endpointURL];

        NSMutableArray<CAThirdPartyAccount *> *nextAccounts = [NSMutableArray arrayWithArray:self.thirdPartyAccounts ?: @[]];
        if (existingAccount) {
            NSUInteger index = [nextAccounts indexOfObjectIdenticalTo:existingAccount];
            if (index == NSNotFound) {
                [self showAlertWithTitle:@"Save Failed" message:@"The Third Party account is no longer available."];
                return;
            }
            nextAccounts[index] = account;
        } else {
            [nextAccounts addObject:account];
        }

        NSError *saveError = nil;
        NSString *previousAPIKey = nil;
        if (existingAccount && apiKey.length > 0) {
            previousAPIKey = [CAThirdPartyAccountStore apiKeyForAccount:existingAccount error:&saveError];
            if (!previousAPIKey) {
                [self showAlertWithTitle:@"Save Failed" message:saveError.localizedDescription ?: @"Failed to read the existing API Key."];
                continue;
            }
        }

        if (![CAThirdPartyAccountStore saveAccounts:nextAccounts error:&saveError]) {
            [self showAlertWithTitle:@"Save Failed" message:saveError.localizedDescription ?: @"Failed to save Third Party account."];
            continue;
        }

        if (apiKey.length > 0 && ![CAThirdPartyAccountStore saveAPIKey:apiKey forAccount:account error:&saveError]) {
            [CAThirdPartyAccountStore saveAccounts:self.thirdPartyAccounts error:nil];
            if (existingAccount) {
                [CAThirdPartyAccountStore saveAPIKey:previousAPIKey ?: @"" forAccount:existingAccount error:nil];
            } else {
                [CAThirdPartyAccountStore deleteAPIKeyForAccount:account error:nil];
            }
            [self showAlertWithTitle:@"Save Failed" message:saveError.localizedDescription ?: @"Failed to save the API Key."];
            continue;
        }

        if ([self.activeThirdPartyAccountID isEqualToString:account.identifier]) {
            NSError *rewriteError = nil;
            if (![self rewriteConfigForActiveThirdPartyAccount:account error:&rewriteError]) {
                NSError *rollbackError = nil;
                BOOL accountsRolledBack = [CAThirdPartyAccountStore saveAccounts:self.thirdPartyAccounts error:&rollbackError];
                BOOL keyRolledBack = YES;
                if (apiKey.length > 0) {
                    keyRolledBack = [CAThirdPartyAccountStore saveAPIKey:previousAPIKey ?: @""
                                                             forAccount:existingAccount
                                                                  error:&rollbackError];
                }
                NSString *message = rewriteError.localizedDescription ?: @"Failed to rewrite the active Codex provider config.";
                if (!accountsRolledBack || !keyRolledBack) {
                    message = [message stringByAppendingFormat:@" Saved account rollback also failed: %@",
                                                            rollbackError.localizedDescription ?: @"unknown error"];
                }
                [self showAlertWithTitle:@"Save Failed" message:message];
                continue;
            }
            [self showAlertWithTitle:@"Third Party Account Updated"
                             message:@"The active Codex provider config has been rewritten. Restart existing Codex sessions to reload the updated values."];
        }

        self.thirdPartyAccounts = nextAccounts;
        self.lastError = nil;
        [self rebuildMenu];
        return;
    }
}

- (void)startCodexAccountLogin {
    NSError *error = nil;
    if (![self.manager startLoginInTerminal:&error]) {
        self.lastError = error.localizedDescription;
        [self rebuildMenu];
        return;
    }

    self.lastError = nil;
    [self rebuildMenu];
}

- (void)addNewAccount:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add New Account";
    alert.informativeText = @"Choose the account type to add.";
    [alert addButtonWithTitle:@"Codex Account"];
    [alert addButtonWithTitle:@"Third Party Account"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleInformational;

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [self startCodexAccountLogin];
    } else if (response == NSAlertSecondButtonReturn) {
        [self showThirdPartyAccountFormForAccount:nil];
    }
}

- (void)editThirdPartyAccount:(NSMenuItem *)sender {
    CAThirdPartyAccount *account = [self thirdPartyAccountWithID:sender.representedObject];
    if (account) [self showThirdPartyAccountFormForAccount:account];
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

- (void)changePollInterval:(NSMenuItem *)sender {
    NSNumber *value = sender.representedObject;
    if (![value isKindOfClass:[NSNumber class]]) return;

    self.pollInterval = value.doubleValue;
    [[NSUserDefaults standardUserDefaults] setDouble:self.pollInterval forKey:CADefaultPollIntervalKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self scheduleTimer];
    [self rebuildMenu];
}

- (void)changeProxyMode:(NSMenuItem *)sender {
    NSString *value = sender.representedObject;
    if (![value isKindOfClass:[NSString class]]) return;

    CAProxyMode nextMode = [value isEqualToString:CAProxyModeSystemValue] ? CAProxyModeSystem : CAProxyModeDirect;
    if (self.proxyMode == nextMode) return;

    self.proxyMode = nextMode;
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:CAProxyModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.lastError = nil;
    [self rebuildMenu];
    [self refresh];
}

- (NSString *)menuBarTitle {
    return [self menuBarUsageTitle];
}

- (void)addStaticItem:(NSString *)title toMenu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.enabled = NO;
    [menu addItem:item];
}

- (NSString *)formattedUpdatedAt {
    if (!self.lastUpdated) return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    return [formatter stringFromDate:self.lastUpdated];
}

- (NSTimeInterval)loadPollInterval {
    NSArray<NSNumber *> *validIntervals = [self supportedPollIntervals];
    double savedInterval = [[NSUserDefaults standardUserDefaults] doubleForKey:CADefaultPollIntervalKey];
    if (savedInterval <= 0) return CADefaultPollInterval;

    for (NSNumber *value in validIntervals) {
        if (fabs(value.doubleValue - savedInterval) < DBL_EPSILON) return value.doubleValue;
    }
    return CADefaultPollInterval;
}

- (CAProxyMode)loadProxyMode {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:CAProxyModeKey];
    if ([saved isEqualToString:CAProxyModeSystemValue]) return CAProxyModeSystem;
    return CAProxyModeDirect;
}

- (NSArray<NSNumber *> *)supportedPollIntervals {
    return @[@60, @300, @600, @1200, @1800, @3600];
}

- (NSString *)labelForPollInterval:(NSTimeInterval)seconds {
    NSInteger minutes = (NSInteger)llround(seconds / 60.0);
    return [NSString stringWithFormat:@"%ldmin", (long)minutes];
}

- (NSString *)trimmedStringOrFallback:(NSString *)value fallback:(NSString *)fallback {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : fallback;
}

- (NSString *)timeComponentFromUsage:(NSString *)usageText {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([^\\)]+)\\)"
                                                                           options:0
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:usageText options:0 range:NSMakeRange(0, usageText.length)];
    if (!match || [match numberOfRanges] < 2) return @"--:--";
    NSString *inside = [usageText substringWithRange:[match rangeAtIndex:1]];
    NSString *trimmed = [inside stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRegularExpression *clockRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\d{1,2}:\\d{2}\\b"
                                                                                options:0
                                                                                  error:nil];
    NSTextCheckingResult *clockMatch = [clockRegex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
    if (clockMatch) {
        return [trimmed substringWithRange:clockMatch.range];
    }
    return [self trimmedStringOrFallback:trimmed fallback:@"--:--"];
}

- (NSString *)dateComponentFromWeeklyUsage:(NSString *)usageText {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"on\\s+(\\d{1,2}\\s+[A-Za-z]{3})"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:usageText options:0 range:NSMakeRange(0, usageText.length)];
    if (!match || [match numberOfRanges] < 2) return @"--月--日";

    NSString *englishDate = [usageText substringWithRange:[match rangeAtIndex:1]];
    NSDateFormatter *parser = [[NSDateFormatter alloc] init];
    parser.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"d MMM";

    NSDate *date = [parser dateFromString:englishDate];
    if (!date) return @"--月--日";

    NSString *languageCode = [[[NSLocale preferredLanguages] firstObject] lowercaseString];
    if ([languageCode hasPrefix:@"zh"]) {
        NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];
        return [NSString stringWithFormat:@"%ld月%ld日", (long)components.month, (long)components.day];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"dd MMM";
    return [formatter stringFromDate:date];
}

- (NSString *)usageSummaryForAccount:(CAAccount *)account {
    NSString *fiveHourPercent = [self trimmedStringOrFallback:[[account.usage5h componentsSeparatedByString:@" "] firstObject] fallback:@"--%"];
    NSString *weeklyPercent = [self trimmedStringOrFallback:[[account.weeklyUsage componentsSeparatedByString:@" "] firstObject] fallback:@"--%"];
    NSString *fiveHourTime = [self timeComponentFromUsage:account.usage5h];
    NSString *weeklyDate = [self dateComponentFromWeeklyUsage:account.weeklyUsage];
    return [NSString stringWithFormat:@"5H %@ %@ | W %@ %@", fiveHourPercent, fiveHourTime, weeklyPercent, weeklyDate];
}

- (NSString *)displayPercentForUsage:(NSInteger)usagePercent {
    return usagePercent == NSNotFound ? @"--%" : [NSString stringWithFormat:@"%ld%%", (long)usagePercent];
}

- (NSColor *)tagBackgroundColorForUsage:(NSInteger)usagePercent {
    if (usagePercent == NSNotFound || usagePercent <= 0) {
        return [NSColor colorWithCalibratedRed:CATagBgRedLow green:CATagBgGreenLow blue:CATagBgBlueLow alpha:1.0];
    }
    if (usagePercent <= 10) {
        return [NSColor colorWithCalibratedRed:CATagBgRedMedium green:CATagBgGreenMedium blue:CATagBgBlueMedium alpha:1.0];
    }
    return [NSColor colorWithCalibratedRed:CATagBgRedHigh green:CATagBgGreenHigh blue:CATagBgBlueHigh alpha:1.0];
}

- (NSColor *)tagForegroundColorForUsage:(NSInteger)usagePercent {
    if (usagePercent == NSNotFound || usagePercent <= 0) {
        return [NSColor colorWithCalibratedRed:CATagFgRedLow green:CATagFgGreenLow blue:CATagFgBlueLow alpha:1.0];
    }
    if (usagePercent <= 10) {
        return [NSColor colorWithCalibratedRed:CATagFgRedMedium green:CATagFgGreenMedium blue:CATagFgBlueMedium alpha:1.0];
    }
    return [NSColor colorWithCalibratedRed:CATagFgRedHigh green:CATagFgGreenHigh blue:CATagFgBlueHigh alpha:1.0];
}

- (NSAttributedString *)tagAttributedStringWithLabel:(NSString *)label
                                            percent:(NSInteger)usagePercent
                                               time:(NSString *)time {
    NSString *displayPercent = [self displayPercentForUsage:usagePercent];
    NSString *displayTime = [self trimmedStringOrFallback:time fallback:@"--"];
    NSString *text = [NSString stringWithFormat:@" %@ %@ %@ ", label, displayPercent, displayTime];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [self tagForegroundColorForUsage:usagePercent],
        NSBackgroundColorAttributeName: [self tagBackgroundColorForUsage:usagePercent]
    };
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)errorTagAttributedStringWithMessage:(NSString *)message {
    NSString *text = [NSString stringWithFormat:@" ⚠ %@ ", message ?: @"错误"];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:CAErrorTagFgRed green:CAErrorTagFgGreen blue:CAErrorTagFgBlue alpha:1.0],
        NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:CAErrorTagBgRed green:CAErrorTagBgGreen blue:CAErrorTagBgBlue alpha:1.0]
    };
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)dashTagAttributedStringWithLabel:(NSString *)label {
    NSString *text = [NSString stringWithFormat:@" %@ - ", label];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [self tagForegroundColorForUsage:NSNotFound],
        NSBackgroundColorAttributeName: [self tagBackgroundColorForUsage:NSNotFound]
    };
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)switchAccountTitleForAccount:(CAAccount *)account {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.tabStops = @[
        [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:CASwitchAccountTabLocation options:@{}]
    ];
    paragraphStyle.defaultTabInterval = CASwitchAccountTabLocation;

    NSDictionary *leftAttributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [NSFont menuFontOfSize:0]
    };

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\t", account.account]
                                                                                attributes:leftAttributes];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:leftAttributes]];

    if (account.health != CAAccountHealthOK) {
        [result appendAttributedString:[self errorTagAttributedStringWithMessage:account.errorMessage ?: @"异常"]];
    } else {
        NSString *trimmed5h = [account.usage5h stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *trimmedW = [account.weeklyUsage stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        BOOL hasDash5h = trimmed5h.length == 0 || [trimmed5h isEqualToString:@"-"];
        BOOL hasDashW = trimmedW.length == 0 || [trimmedW isEqualToString:@"-"];

        if (hasDash5h) {
            [result appendAttributedString:[self dashTagAttributedStringWithLabel:@"5H"]];
        } else {
            NSInteger fiveHourUsage = [self usagePercentFromString:account.usage5h];
            NSString *fiveHourTime = [self timeComponentFromUsage:account.usage5h];
            [result appendAttributedString:[self tagAttributedStringWithLabel:@"5H"
                                                                  percent:fiveHourUsage
                                                                     time:fiveHourTime]];
        }
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"   " attributes:leftAttributes]];
        if (hasDashW) {
            [result appendAttributedString:[self dashTagAttributedStringWithLabel:@"W"]];
        } else {
            NSInteger weeklyUsage = [self usagePercentFromString:account.weeklyUsage];
            NSString *weeklyTime = [self dateComponentFromWeeklyUsage:account.weeklyUsage];
            [result appendAttributedString:[self tagAttributedStringWithLabel:@"W"
                                                                  percent:weeklyUsage
                                                                     time:weeklyTime]];
        }
    }
    return result;
}

- (NSString *)currentAccountUsageLineWithLabel:(NSString *)label
                                     usageText:(NSString *)usageText
                                   timeDisplay:(NSString *)timeDisplay {
    NSString *trimmed = [usageText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0 || [trimmed isEqualToString:@"-"]) {
        return [NSString stringWithFormat:@"%@: -", label];
    }
    NSInteger usedPercent = [self usagePercentFromString:usageText];
    if (usedPercent == NSNotFound) {
        return [NSString stringWithFormat:@"%@: %@", label, timeDisplay ?: @""];
    }
    return [NSString stringWithFormat:@"%@: %ld%% %@", label, (long)usedPercent, timeDisplay];
}

- (NSAttributedString *)currentAccountErrorLineForAccount:(CAAccount *)account {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.tabStops = @[
        [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:230 options:@{}]
    ];
    paragraphStyle.defaultTabInterval = 230;

    NSDictionary *leftAttributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [NSFont menuFontOfSize:0]
    };

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@"账号状态\t"
                                                                                attributes:leftAttributes];
    [result appendAttributedString:[self errorTagAttributedStringWithMessage:account.errorMessage ?: @"异常"]];
    return result;
}

- (NSString *)switchAccountMenuTitleForActiveAccount:(CAAccount *)activeAccount {
    if (activeAccount.account.length > 0) {
        return activeAccount.account;
    }
    return @"No active account";
}

- (NSAttributedString *)alignedMenuTitleWithLeft:(NSString *)left right:(NSString *)right {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.tabStops = @[
        [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:CAAlignedMenuTabLocation options:@{}]
    ];
    paragraphStyle.defaultTabInterval = CAAlignedMenuTabLocation;

    NSDictionary *attributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [NSFont menuFontOfSize:0]
    };
    NSString *composed = [NSString stringWithFormat:@"%@\t%@", left, right];
    return [[NSAttributedString alloc] initWithString:composed attributes:attributes];
}

- (NSAttributedString *)planTagAttributedStringForPlan:(NSString *)plan {
    NSString *text = [NSString stringWithFormat:@" %@ ", [self trimmedStringOrFallback:plan fallback:@"Unknown"]];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:CAPlanTagFgRed green:CAPlanTagFgGreen blue:CAPlanTagFgBlue alpha:1.0],
        NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:CAPlanTagBgRed green:CAPlanTagBgGreen blue:CAPlanTagBgBlue alpha:1.0]
    };
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)thirdPartyTagAttributedString {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:CAThirdPartyTagFgRed green:CAThirdPartyTagFgGreen blue:CAThirdPartyTagFgBlue alpha:1.0],
        NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:CAThirdPartyTagBgRed green:CAThirdPartyTagBgGreen blue:CAThirdPartyTagBgBlue alpha:1.0]
    };
    return [[NSAttributedString alloc] initWithString:@" Third Party " attributes:attributes];
}

- (NSAttributedString *)requiresRoutingTagAttributedString {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:CAErrorTagFgRed green:CAErrorTagFgGreen blue:CAErrorTagFgBlue alpha:1.0],
        NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:CAErrorTagBgRed green:CAErrorTagBgGreen blue:CAErrorTagBgBlue alpha:1.0]
    };
    return [[NSAttributedString alloc] initWithString:@" Requires Routing " attributes:attributes];
}

- (NSAttributedString *)currentAccountHeaderForAccount:(CAAccount *)account {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.tabStops = @[
        [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:CAAlignedMenuTabLocation options:@{}]
    ];
    paragraphStyle.defaultTabInterval = CAAlignedMenuTabLocation;

    NSDictionary *leftAttributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [NSFont menuFontOfSize:0]
    };

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@"Current Account\t"
                                                                                attributes:leftAttributes];
    [result appendAttributedString:[self planTagAttributedStringForPlan:account.plan]];
    return result;
}

- (NSAttributedString *)currentAccountHeaderForThirdPartyAccount:(CAThirdPartyAccount *)account {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.tabStops = @[
        [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:CAAlignedMenuTabLocation options:@{}]
    ];
    paragraphStyle.defaultTabInterval = CAAlignedMenuTabLocation;

    NSDictionary *leftAttributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [NSFont menuFontOfSize:0]
    };

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@"Current Account\t"
                                                                                attributes:leftAttributes];
    [result appendAttributedString:[self planTagAttributedStringForPlan:account.providerName]];
    return result;
}

- (NSAttributedString *)switchAccountTitleForThirdPartyAccount:(CAThirdPartyAccount *)account {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.tabStops = @[
        [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:CASwitchAccountTabLocation options:@{}]
    ];
    paragraphStyle.defaultTabInterval = CASwitchAccountTabLocation;

    NSDictionary *leftAttributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [NSFont menuFontOfSize:0]
    };

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\t", account.remark]
                                                                                attributes:leftAttributes];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:leftAttributes]];
    [result appendAttributedString:([account isChatCompletionsOnly] ? [self requiresRoutingTagAttributedString] : [self thirdPartyTagAttributedString])];
    return result;
}

- (void)scheduleTimer {
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.pollInterval
                                                  target:self
                                                selector:@selector(refresh)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)refreshNotificationSettings {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        CANotificationStatus status = CANotificationStatusNotDetermined;
        switch (settings.authorizationStatus) {
            case UNAuthorizationStatusAuthorized:
            case UNAuthorizationStatusProvisional:
                status = CANotificationStatusEnabled;
                break;
            case UNAuthorizationStatusDenied:
                status = CANotificationStatusDenied;
                break;
            case UNAuthorizationStatusNotDetermined:
            default:
                status = CANotificationStatusNotDetermined;
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.notificationStatus = status;
            [self rebuildMenu];
        });
    }];
}

- (NSString *)notificationStatusText {
    switch (self.notificationStatus) {
        case CANotificationStatusEnabled:
            return @"enabled";
        case CANotificationStatusDenied:
            return @"denied";
        case CANotificationStatusNotDetermined:
        default:
            return @"not determined";
    }
}

- (NSInteger)usagePercentFromString:(NSString *)usageText {
    NSRange percentRange = [usageText rangeOfString:@"%"];
    if (percentRange.location == NSNotFound) return NSNotFound;
    NSString *prefix = [usageText substringToIndex:percentRange.location];
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *digits = [[prefix componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    if (digits.length == 0) return NSNotFound;
    return digits.integerValue;
}

- (NSDictionary<NSString *, NSString *> *)triggeredReasonsForAccount:(CAAccount *)account {
    NSMutableDictionary<NSString *, NSString *> *reasons = [NSMutableDictionary dictionary];
    NSInteger fiveHour = [self usagePercentFromString:account.usage5h];
    NSInteger weekly = [self usagePercentFromString:account.weeklyUsage];
    if (fiveHour != NSNotFound && fiveHour >= 90) {
        reasons[@"5h"] = account.usage5h;
    }
    if (weekly != NSNotFound && weekly >= 90) {
        reasons[@"weekly"] = account.weeklyUsage;
    }
    return reasons;
}

- (NSString *)notificationKeyForAccount:(CAAccount *)account reasons:(NSDictionary<NSString *, NSString *> *)reasons {
    NSArray<NSString *> *reasonKeys = [[reasons allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSString *reasonPart = [reasonKeys componentsJoinedByString:@"+"];
    return [NSString stringWithFormat:@"%@|%@|%@|%@", account.account, account.usage5h, account.weeklyUsage, reasonPart];
}

- (void)notifyIfNeededForAccounts:(NSArray<CAAccount *> *)accounts {
    for (CAAccount *account in accounts) {
        NSDictionary<NSString *, NSString *> *reasons = [self triggeredReasonsForAccount:account];
        if (reasons.count == 0) continue;

        NSString *dedupKey = [self notificationKeyForAccount:account reasons:reasons];
        NSMutableDictionary *dedupMap = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:CANotificationDedupKey] mutableCopy];
        if (!dedupMap) dedupMap = [NSMutableDictionary dictionary];
        NSString *previousKey = dedupMap[account.account];
        if ([previousKey isEqualToString:dedupKey]) continue;

        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (reasons[@"5h"]) [parts addObject:[NSString stringWithFormat:@"5h usage %@", reasons[@"5h"]]];
        if (reasons[@"weekly"]) [parts addObject:[NSString stringWithFormat:@"weekly usage %@", reasons[@"weekly"]]];
        NSString *body = [parts componentsJoinedByString:@" • "];

        [self deliverThresholdNotificationForAccount:account.account
                                                body:body
                                           dedupKey:dedupKey];
        break;
    }
}

- (void)deliverThresholdNotificationForAccount:(NSString *)account
                                          body:(NSString *)body
                                     dedupKey:(NSString *)dedupKey {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    __weak typeof(self) weakSelf = self;
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        UNAuthorizationStatus authorizationStatus = settings.authorizationStatus;
        if (authorizationStatus == UNAuthorizationStatusDenied) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.notificationStatus = CANotificationStatusDenied;
                [weakSelf rebuildMenu];
            });
            return;
        }

        void (^sendNotification)(void) = ^{
            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.title = @"Codex usage is close to the limit";
            content.body = [NSString stringWithFormat:@"%@: %@", account, body];
            content.sound = [UNNotificationSound defaultSound];

            NSString *identifier = [NSString stringWithFormat:@"usage-%@", dedupKey];
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                                  content:content
                                                                                  trigger:nil];
            [center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        if (CAIsNotificationsNotAllowedError(error)) {
                            weakSelf.notificationStatus = CANotificationStatusDenied;
                        } else {
                            weakSelf.lastError = error.localizedDescription;
                        }
                    } else {
                        NSMutableDictionary *dedupMap = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:CANotificationDedupKey] mutableCopy];
                        if (!dedupMap) dedupMap = [NSMutableDictionary dictionary];
                        dedupMap[account] = dedupKey;
                        [[NSUserDefaults standardUserDefaults] setObject:dedupMap forKey:CANotificationDedupKey];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        weakSelf.notificationStatus = CANotificationStatusEnabled;
                    }
                    [weakSelf rebuildMenu];
                });
            }];
        };

        if (authorizationStatus == UNAuthorizationStatusNotDetermined) {
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                                  completionHandler:^(BOOL granted, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        if (CAIsNotificationsNotAllowedError(error)) {
                            weakSelf.notificationStatus = CANotificationStatusDenied;
                        } else {
                            weakSelf.lastError = error.localizedDescription;
                        }
                    }
                    weakSelf.notificationStatus = granted ? CANotificationStatusEnabled : CANotificationStatusDenied;
                    [weakSelf rebuildMenu];
                });
                if (granted) {
                    sendNotification();
                }
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.notificationStatus = CANotificationStatusEnabled;
                [weakSelf rebuildMenu];
            });
            sendNotification();
        }
    }];
}

- (void)rebuildMenu {
    [self updateStatusItemButton];
    NSMenu *menu = [[NSMenu alloc] init];
    CAThirdPartyAccount *activeThirdParty = [self activeThirdPartyAccount];
    CAAccount *active = nil;
    for (CAAccount *account in self.accounts) {
        if (account.active) {
            active = account;
            break;
        }
    }

    if (activeThirdParty || active) {
        NSMenuItem *currentHeaderItem = [[NSMenuItem alloc] initWithTitle:@"Current Account" action:nil keyEquivalent:@""];
        currentHeaderItem.enabled = NO;
        currentHeaderItem.attributedTitle = activeThirdParty ? [self currentAccountHeaderForThirdPartyAccount:activeThirdParty] : [self currentAccountHeaderForAccount:active];
        [menu addItem:currentHeaderItem];

        NSString *headerTitle = activeThirdParty ? activeThirdParty.remark : active.account;
        NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:headerTitle action:nil keyEquivalent:@""];
        NSMenu *switchAccountSubmenu = [[NSMenu alloc] initWithTitle:@"Switch Account"];
        if (self.accounts.count == 0 && self.thirdPartyAccounts.count == 0) {
            NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:(self.refreshing ? @"Refreshing..." : @"No accounts found")
                                                               action:nil
                                                        keyEquivalent:@""];
            emptyItem.enabled = NO;
            [switchAccountSubmenu addItem:emptyItem];
        } else {
            for (CAAccount *account in self.accounts) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:account.account action:@selector(switchAccount:) keyEquivalent:@""];
                item.target = self;
                item.representedObject = account.account;
                item.enabled = (activeThirdParty != nil || !account.active) && !self.switching;
                item.state = (!activeThirdParty && account.active) ? NSControlStateValueOn : NSControlStateValueOff;
                item.attributedTitle = [self switchAccountTitleForAccount:account];
                [switchAccountSubmenu addItem:item];
            }
            if (self.accounts.count > 0 && self.thirdPartyAccounts.count > 0) {
                [switchAccountSubmenu addItem:[NSMenuItem separatorItem]];
            }
            for (CAThirdPartyAccount *thirdParty in self.thirdPartyAccounts) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:thirdParty.remark
                                                              action:@selector(switchThirdPartyAccount:)
                                                       keyEquivalent:@""];
                item.target = self;
                item.representedObject = thirdParty.identifier;
                BOOL isActiveThirdParty = activeThirdParty != nil &&
                    [thirdParty.identifier isEqualToString:activeThirdParty.identifier];
                item.enabled = !isActiveThirdParty && !self.switching;
                item.state = isActiveThirdParty ? NSControlStateValueOn : NSControlStateValueOff;
                item.attributedTitle = [self switchAccountTitleForThirdPartyAccount:thirdParty];
                [switchAccountSubmenu addItem:item];
            }
        }
        headerItem.submenu = switchAccountSubmenu;
        [menu addItem:headerItem];
        if (!activeThirdParty && active.health != CAAccountHealthOK) {
            NSMenuItem *errorItem = [[NSMenuItem alloc] initWithTitle:@"账号状态" action:nil keyEquivalent:@""];
            errorItem.enabled = NO;
            errorItem.attributedTitle = [self currentAccountErrorLineForAccount:active];
            [menu addItem:errorItem];
        } else if (!activeThirdParty) {
            [self addStaticItem:[self currentAccountUsageLineWithLabel:@"5H"
                                                             usageText:active.usage5h
                                                           timeDisplay:[self timeComponentFromUsage:active.usage5h]]
                         toMenu:menu];
            [self addStaticItem:[self currentAccountUsageLineWithLabel:@"W"
                                                             usageText:active.weeklyUsage
                                                           timeDisplay:[self dateComponentFromWeeklyUsage:active.weeklyUsage]]
                         toMenu:menu];
        }
    } else {
        [self addStaticItem:@"Current Account" toMenu:menu];
        NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:(self.refreshing ? @"Refreshing..." : @"No active account")
                                                            action:nil
                                                     keyEquivalent:@""];
        if (self.accounts.count > 0 || self.thirdPartyAccounts.count > 0) {
            NSMenu *switchAccountSubmenu = [[NSMenu alloc] initWithTitle:@"Switch Account"];
            for (CAAccount *account in self.accounts) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:account.account action:@selector(switchAccount:) keyEquivalent:@""];
                item.target = self;
                item.representedObject = account.account;
                item.enabled = !self.switching;
                item.attributedTitle = [self switchAccountTitleForAccount:account];
                [switchAccountSubmenu addItem:item];
            }
            if (self.accounts.count > 0 && self.thirdPartyAccounts.count > 0) {
                [switchAccountSubmenu addItem:[NSMenuItem separatorItem]];
            }
            for (CAThirdPartyAccount *thirdParty in self.thirdPartyAccounts) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:thirdParty.remark
                                                              action:@selector(switchThirdPartyAccount:)
                                                       keyEquivalent:@""];
                item.target = self;
                item.representedObject = thirdParty.identifier;
                item.enabled = !self.switching;
                item.attributedTitle = [self switchAccountTitleForThirdPartyAccount:thirdParty];
                [switchAccountSubmenu addItem:item];
            }
            headerItem.submenu = switchAccountSubmenu;
        } else {
            headerItem.enabled = NO;
        }
        [menu addItem:headerItem];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *queryIntervalItem = [[NSMenuItem alloc] initWithTitle:@"Query Interval" action:nil keyEquivalent:@""];
    NSMenu *queryIntervalSubmenu = [[NSMenu alloc] initWithTitle:@"Query Interval"];
    for (NSNumber *interval in [self supportedPollIntervals]) {
        NSTimeInterval value = interval.doubleValue;
        NSString *title = [self labelForPollInterval:value];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(changePollInterval:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = interval;
        item.state = fabs(value - self.pollInterval) < DBL_EPSILON ? NSControlStateValueOn : NSControlStateValueOff;
        [queryIntervalSubmenu addItem:item];
    }
    queryIntervalItem.submenu = queryIntervalSubmenu;
    [menu addItem:queryIntervalItem];

    NSMenuItem *proxyModeItem = [[NSMenuItem alloc] initWithTitle:@"Proxy Mode" action:nil keyEquivalent:@""];
    NSMenu *proxyModeSubmenu = [[NSMenu alloc] initWithTitle:@"Proxy Mode"];
    NSArray<NSDictionary<NSString *, NSString *> *> *proxyModes = @[
        @{@"title": @"Direct", @"value": CAProxyModeDirectValue},
        @{@"title": @"System Proxy", @"value": CAProxyModeSystemValue}
    ];
    for (NSDictionary<NSString *, NSString *> *proxyMode in proxyModes) {
        NSString *value = proxyMode[@"value"];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:proxyMode[@"title"]
                                                      action:@selector(changeProxyMode:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = value;
        item.state = (([value isEqualToString:CAProxyModeSystemValue] && self.proxyMode == CAProxyModeSystem) ||
                      ([value isEqualToString:CAProxyModeDirectValue] && self.proxyMode == CAProxyModeDirect))
                     ? NSControlStateValueOn
                     : NSControlStateValueOff;
        [proxyModeSubmenu addItem:item];
    }
    proxyModeItem.submenu = proxyModeSubmenu;
    [menu addItem:proxyModeItem];

    [menu addItem:[NSMenuItem separatorItem]];
    NSString *toggleTitle = [[self.status.autoSwitch uppercaseString] isEqualToString:@"ON"] ? @"Disable Auto Switch" : @"Enable Auto Switch";
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:toggleTitle action:@selector(toggleAutoSwitch:) keyEquivalent:@""];
    toggleItem.target = self;
    toggleItem.enabled = !self.refreshing && !self.switching;
    [menu addItem:toggleItem];

    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:(self.refreshing ? @"Refreshing..." : @"Refresh Now")
                                                         action:@selector(refresh)
                                                  keyEquivalent:@""];
    refreshItem.target = self;
    refreshItem.enabled = !self.refreshing;
    [menu addItem:refreshItem];

    NSMenuItem *terminalItem = [[NSMenuItem alloc] initWithTitle:@"Open In Terminal"
                                                          action:@selector(openInTerminal:)
                                                   keyEquivalent:@""];
    terminalItem.target = self;
    [menu addItem:terminalItem];

    NSMenuItem *addAccountItem = [[NSMenuItem alloc] initWithTitle:@"Add New Account"
                                                            action:@selector(addNewAccount:)
                                                     keyEquivalent:@""];
    addAccountItem.target = self;
    addAccountItem.enabled = !self.switching;
    [menu addItem:addAccountItem];

    if (self.thirdPartyAccounts.count > 0) {
        NSMenuItem *manageThirdPartyItem = [[NSMenuItem alloc] initWithTitle:@"Manage Third Party Account"
                                                                      action:nil
                                                               keyEquivalent:@""];
        NSMenu *manageThirdPartySubmenu = [[NSMenu alloc] initWithTitle:@"Manage Third Party Account"];
        for (CAThirdPartyAccount *thirdParty in self.thirdPartyAccounts) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:thirdParty.remark
                                                          action:@selector(editThirdPartyAccount:)
                                                   keyEquivalent:@""];
            item.target = self;
            item.representedObject = thirdParty.identifier;
            [manageThirdPartySubmenu addItem:item];
        }
        manageThirdPartyItem.submenu = manageThirdPartySubmenu;
        [menu addItem:manageThirdPartyItem];
    }

    NSString *updated = [self formattedUpdatedAt];
    if (updated) [self addStaticItem:[NSString stringWithFormat:@"Updated: %@", updated] toMenu:menu];
    if (self.lastError.length > 0) [self addStaticItem:[NSString stringWithFormat:@"Error: %@", self.lastError] toMenu:menu];

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

@end

static int CARunConfigRoundTripVerification(void) {
    CAThirdPartyAccount *account = [[CAThirdPartyAccount alloc] init];
    account.identifier = @"verify";
    account.remark = @"verify-provider";
    account.providerName = @"VerifyProvider";
    account.endpointURL = @"https://api.verify.example/v1";
    account.endpointType = CAThirdPartyEndpointBaseURLValue;
    account.modelName = @"verify-model";
    account.apiFormat = CAThirdPartyAPIFormatResponsesValue;
    account.keychainIdentifier = @"verify";
    account.codexProviderID = @"codex_auth_menu_verify";

    NSString *original = @"sandbox_mode = \"workspace-write\"\n"
                         "model_provider = \"openai\"\n"
                         "model = \"gpt-5.5\"\n"
                         "\n"
                         "[model_providers.codex_auth_menu_deleted]\n"
                         "name = \"stale\"\n"
                         "base_url = \"https://stale.example\"\n"
                         "\n"
                         "[mcp_servers.demo]\n"
                         "command = \"demo\"\n";
    NSDictionary *snapshot = [CACodexConfigManager snapshotFromConfigText:original];
    NSError *error = nil;
    NSString *applied = [CACodexConfigManager configTextByApplyingThirdPartyAccount:account
                                                                             apiKey:@"sk-verify"
                                                                             toText:original
                                                                              error:&error];
    if (!applied ||
        ![applied containsString:@"model_provider = \"codex_auth_menu_verify\""] ||
        ![applied containsString:@"[model_providers.codex_auth_menu_verify]"] ||
        [applied containsString:@"codex_auth_menu_deleted"] ||
        [applied containsString:@"experimental_bearer_token"] ||
        ![applied containsString:@"[mcp_servers.demo]"]) {
        fprintf(stderr, "Third Party config apply verification failed: %s\n", error.localizedDescription.UTF8String ?: "");
        return 1;
    }

    NSString *restored = [CACodexConfigManager configTextByRestoringSnapshot:snapshot
                                                         removingProviderIDs:@[account.codexProviderID]
                                                                    fromText:applied];
    if (![restored containsString:@"model_provider = \"openai\""] ||
        ![restored containsString:@"model = \"gpt-5.5\""] ||
        ![restored containsString:@"[mcp_servers.demo]"] ||
        [restored containsString:@"codex_auth_menu_verify"] ||
        [restored containsString:@"disable_response_storage"]) {
        fprintf(stderr, "Official config restore verification failed.\n");
        return 1;
    }

    printf("Config roundtrip verification passed.\n");
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--verify-config-roundtrip") == 0) {
            return CARunConfigRoundTripVerification();
        }
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
