# DocB

DocB is a native app for reading DocC documentation wherever you are.

It is designed for the moments where you want to quickly check an API, save something for later, or keep reading docs away from your desk. On the Mac, DocB can also put documentation search one shortcut away, even when the app is not the frontmost window.

Just add the DocC sources you use and start reading. DocB is also compatible with Apple Developer Documentation, so your reference material can live in one place instead of being scattered across browser tabs.

Under the hood, DocB is built with SwiftUI and uses [DocCKit](https://github.com/Mcrich-LLC/DocCKit) for DocC loading, parsing, and rendering.

## Features

- Browse DocC documentation in a native app
- Add popular documentation sources or paste in your own DocC site
- Search across all of your sources
- Save bookmarks and bookmark collections
- Sync sources and bookmarks with CloudKit
- Customizable shortcuts

## Requirements

- Xcode 26 or newer
- Swift 6.2 or newer

### Minimum Targets

- macOS 15
- iOS 18
- visionOS 2

## Getting Started

Clone the repo and open the Xcode project, then select `DocB` scheme.

Build and run from Xcode.

> Note: The app targets use CloudKit entitlements, so you may need to update signing settings before running on your own machine or device.

## Adding Documentation Sources

DocB is built around DocC sources.

You can add normal DocC websites or archives, including documentation hosted on Swift Package Index and other static DocC sites. Apple Developer Documentation is compatible too, but it is just one supported source, not the whole point of the app.

You can add sources from the Add Sources UI. Some sources are already listed as quick options, including Swift.org, Swift Testing, Swift Syntax, RevenueCat, and WWDC Notes.

You can also paste in a custom DocC URL, as long as the site exposes a normal DocC index.

## Search

DocB has a shared search system that indexes the currently loaded documentation sources.

On macOS, search appears as an Open Quickly style panel and can be opened with a keyboard shortcut. On iPadOS, it appears as an overlay. On visionOS, it appears in its own window.

Search results are grouped by source, so different documentation sets stay easy to tell apart.

## Bookmarks and Sync

DocB stores bookmarks, bookmark collections, and documentation sources with SwiftData.

CloudKit sync is handled manually through MYCloudKit instead of SwiftData's automatic CloudKit mirroring. This keeps DocB in control of what gets synced and avoids uploading large DocC indexes when only source metadata is needed.

## Project Structure
Most of the code lives in `Sources/DocBCore`, so you can integrate pieces of DocB into your app as well!

Some important pieces:

- `DocumentationViewModel` loads DocC sources, Apple Documentation, frameworks, and articles.
- `ContentView` owns the main documentation browsing UI.
- `AddTechnologyView` handles adding and removing documentation sources.
- `Search/` contains the search index and platform-specific search UIs.
- `SwiftData Models/` contains sources, bookmarks, collections, and sync models.
- `DocBCloudSyncEngine` handles CloudKit sync.

## Building Documentation

To generate a DocC documentation html archive for `DocBCore`, run:

```sh
./build-docs.sh
```

This writes the generated static documentation to `./docs`.

## Contributing

Before opening a pull request, please:

1. Keep changes focused.
2. Match the existing SwiftUI and SwiftData patterns.
3. Please add tests, especially when changing search, persistence, sync, or routing behavior.
4. Make sure the app builds locally.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the pull request process.

## License

This repository is distributed under the license included with the project.
