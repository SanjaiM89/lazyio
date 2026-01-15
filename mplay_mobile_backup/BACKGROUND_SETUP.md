# Background Audio Configuration

Since this is a fresh project, you will need to apply the following native configurations after running `flutter create .` (if you haven't already).

## Android Setup (`android/app/src/main/AndroidManifest.xml`)

Add the following permissions and service declaration inside the `<manifest>` and `<application>` tags:

1. **Permissions** (inside `<manifest>` tag, above `<application>`):
    ```xml
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <!-- For apps targeting Android 14 (API 34) and above -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    ```

2. **Service Declaration** (inside `<application>` tag):
    ```xml
    <activity ...>
        <!-- ... existing activity code ... -->
    </activity>

    <!-- ADD THIS SERVICE -->
    <service android:name="com.ryanheise.audioservice.AudioService"
        android:foregroundServiceType="mediaPlayback"
        android:exported="true">
        <intent-filter>
            <action android:name="android.media.browse.MediaBrowserService" />
        </intent-filter>
    </service>
    
    <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MEDIA_BUTTON" />
        </intent-filter>
    </receiver> 
    ```

## iOS Setup (`ios/Runner/Info.plist`)

Add the following keys to your `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

*(Note: `NSAppTransportSecurity` allows loading audio from `http` URLs, required for localhost/development).*

## Run

After adding these, perform a full restart:
```bash
flutter clean
flutter run
```
