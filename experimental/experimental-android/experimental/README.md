## Android Experimental Wrapper

This module wraps the COMMUNITY Android AAR distributed through GitHub Releases.

Metadata source: `io-android-community.properties`

Required values:

- `IO_ANDROID_VERSION`
- `IO_ANDROID_AAR_URL`
- `IO_ANDROID_AAR_SHA256`

Build flow:

1. Download AAR from release URL.
2. Verify SHA-256 checksum.
3. Expose the verified AAR as an `api` dependency for consumers.
