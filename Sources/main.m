#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreFoundation/CFDictionary.h>

static NSString *const CAErrorDomain = @"CodexAuthMenu";
static NSString *const CADefaultPollIntervalKey = @"pollIntervalSeconds";
static NSString *const CANotificationDedupKey = @"notificationDedupByAccount";
static NSString *const CACliName = @"codex-auth";
static NSString *const CANodeName = @"node";
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

typedef NS_ENUM(NSInteger, CANotificationStatus) {
    CANotificationStatusNotDetermined = 0,
    CANotificationStatusEnabled = 1,
    CANotificationStatusDenied = 2,
};

static BOOL CAIsNotificationsNotAllowedError(NSError *error) {
    return error != nil &&
           [error.domain isEqualToString:UNErrorDomain] &&
           error.code == UNErrorCodeNotificationsNotAllowed;
}

@interface CAAccount : NSObject
@property(nonatomic, assign) BOOL active;
@property(nonatomic, copy) NSString *index;
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSString *plan;
@property(nonatomic, copy) NSString *usage5h;
@property(nonatomic, copy) NSString *weeklyUsage;
@property(nonatomic, copy) NSString *lastActivity;
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
    task.arguments = @[ @"-l", @"-c", [NSString stringWithFormat:@"which %@", command] ];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        return nil;
    }
    if (task.terminationStatus != 0) return nil;
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (instancetype)initWithBinaryPath:(NSString *)binaryPath nodePath:(NSString *)nodePath {
    self = [super init];
    if (self) {
        _binaryPath = binaryPath ?: [CodexAuthManager resolvePathForCommand:CACliName];
        _nodePath = nodePath ?: [CodexAuthManager resolvePathForCommand:CANodeName];
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

- (BOOL)openInTerminal:(NSError **)error {
    NSString *script = [NSString stringWithFormat:
                        @"tell application \"Terminal\"\n"
                        "activate\n"
                        "do script \"%@ status; %@ list\"\n"
                        "end tell", self.binaryPath, self.binaryPath];
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
    NSString *script = [NSString stringWithFormat:
                        @"tell application \"Terminal\"\n"
                        "activate\n"
                        "do script \"%@ %@ login\"\n"
                        "end tell", self.nodePath, self.binaryPath];
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

- (NSString *)systemProxyURL {
    NSDictionary *services = (__bridge_transfer NSDictionary *)CFNetworkCopySystemProxySettings();
    if (!services) return nil;
    NSNumber *httpEnable = services[(__bridge NSString *)kCFNetworkProxiesHTTPEnable];
    if (![httpEnable boolValue]) return nil;
    NSString *host = services[(__bridge NSString *)kCFNetworkProxiesHTTPProxy];
    NSNumber *port = services[(__bridge NSString *)kCFNetworkProxiesHTTPPort];
    if (!host || host.length == 0 || !port) return nil;
    return [NSString stringWithFormat:@"http://%@:%@", host, port];
}

- (NSString *)run:(NSArray<NSString *> *)arguments error:(NSError **)error {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/zsh";

    NSMutableArray<NSString *> *cmdParts = [NSMutableArray arrayWithObject:self.binaryPath];
    [cmdParts addObjectsFromArray:arguments];
    NSString *joinedCmd = [cmdParts componentsJoinedByString:@" "];
    task.arguments = @[ @"-l", @"-c", joinedCmd ];

    NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    NSString *proxyURL = [self systemProxyURL];
    if (proxyURL.length > 0) {
        if (!env[@"http_proxy"]) env[@"http_proxy"] = proxyURL;
        if (!env[@"https_proxy"]) env[@"https_proxy"] = proxyURL;
        if (!env[@"ALL_PROXY"]) env[@"ALL_PROXY"] = proxyURL;
    }
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
@property(nonatomic, assign) CANotificationStatus notificationStatus;
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
    for (CAAccount *account in self.accounts) {
        if (account.active) {
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

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.manager = [[CodexAuthManager alloc] init];
    self.status = [[CAStatusSnapshot alloc] init];
    self.accounts = @[];
    self.notificationStatus = CANotificationStatusNotDetermined;
    self.pollInterval = [self loadPollInterval];
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
        BOOL success = [self.manager switchAccount:account error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.switching = NO;
            if (success) [self refresh];
            else {
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

- (void)addNewAccount:(id)sender {
    NSError *error = nil;
    if (![self.manager startLoginInTerminal:&error]) {
        self.lastError = error.localizedDescription;
        [self rebuildMenu];
        return;
    }

    self.lastError = nil;
    [self rebuildMenu];
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

    NSInteger fiveHourUsage = [self usagePercentFromString:account.usage5h];
    NSInteger weeklyUsage = [self usagePercentFromString:account.weeklyUsage];
    NSString *fiveHourTime = [self timeComponentFromUsage:account.usage5h];
    NSString *weeklyTime = [self dateComponentFromWeeklyUsage:account.weeklyUsage];

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\t", account.account]
                                                                                attributes:leftAttributes];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:leftAttributes]];
    [result appendAttributedString:[self tagAttributedStringWithLabel:@"5H"
                                                              percent:fiveHourUsage
                                                                 time:fiveHourTime]];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"   " attributes:leftAttributes]];
    [result appendAttributedString:[self tagAttributedStringWithLabel:@"W"
                                                              percent:weeklyUsage
                                                                 time:weeklyTime]];
    return result;
}

- (NSString *)currentAccountUsageLineWithLabel:(NSString *)label
                                     usageText:(NSString *)usageText
                                   timeDisplay:(NSString *)timeDisplay {
    NSInteger usedPercent = [self usagePercentFromString:usageText];
    return [NSString stringWithFormat:@"%@: %ld%% %@", label, (long)usedPercent, timeDisplay];
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
    CAAccount *active = nil;
    for (CAAccount *account in self.accounts) {
        if (account.active) {
            active = account;
            break;
        }
    }

    if (active) {
        NSMenuItem *currentHeaderItem = [[NSMenuItem alloc] initWithTitle:@"Current Account" action:nil keyEquivalent:@""];
        currentHeaderItem.enabled = NO;
        currentHeaderItem.attributedTitle = [self currentAccountHeaderForAccount:active];
        [menu addItem:currentHeaderItem];

        NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:active.account action:nil keyEquivalent:@""];
        NSMenu *switchAccountSubmenu = [[NSMenu alloc] initWithTitle:@"Switch Account"];
        if (self.accounts.count == 0) {
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
                item.enabled = !account.active && !self.switching;
                item.state = account.active ? NSControlStateValueOn : NSControlStateValueOff;
                item.attributedTitle = [self switchAccountTitleForAccount:account];
                [switchAccountSubmenu addItem:item];
            }
        }
        headerItem.submenu = switchAccountSubmenu;
        [menu addItem:headerItem];
        [self addStaticItem:[self currentAccountUsageLineWithLabel:@"5H"
                                                         usageText:active.usage5h
                                                       timeDisplay:[self timeComponentFromUsage:active.usage5h]]
                     toMenu:menu];
        [self addStaticItem:[self currentAccountUsageLineWithLabel:@"W"
                                                         usageText:active.weeklyUsage
                                                       timeDisplay:[self dateComponentFromWeeklyUsage:active.weeklyUsage]]
                     toMenu:menu];
    } else {
        [self addStaticItem:@"Current Account" toMenu:menu];
        [self addStaticItem:(self.refreshing ? @"Refreshing..." : @"No active account") toMenu:menu];
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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
