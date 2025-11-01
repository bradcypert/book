# Book

Book is a simple program for managing and opening bookmarks in your terminal. The aim is to essentially be "go links" but for your terminal and local to your machine.

Book is backed by a CSV file, making it extremely easy to share bookmarks or manipulate your bookmarks with your own programs as well.

## Basic Usage

```bash
# Add a new bookmark "gh" pointing to github.com
book gh https://www.github.com

# Add a bookmark with tags (comma-separated)
book gh https://www.github.com --tags dev,code,social

# Open the "gh" bookmark (opens in your default browser)
book gh
```

## Listing bookmarks

```bash
# List all bookmarks
book --list
```

## Searching for bookmarks

```bash
# Search all bookmarks for the word "github" in the bookmark value, path, or tag
book --search github
```

## Exporting bookmarks

```bash
# Export all bookmarks to stdout
book --export

# Export bookmarks with specific tags to stdout
book --export --tags dev,code

# Export all bookmarks to a file
book --export --output bookmarks.csv
# Or use the short flag
book --export -o bookmarks.csv

# Export bookmarks with specific tags to a file
book --export --tags dev,code --output dev_bookmarks.csv
```

## Deleting bookmarks

```bash
# Delete a specific bookmark by key
book --delete gh

# Delete all bookmarks (prompts for confirmation)
book --deleteAll

# Delete all bookmarks without confirmation
book --deleteAll --yes
```

## Interactive TUI Mode

```bash
# Launch interactive terminal UI (no arguments)
book
```

## Where are my bookmarks, though?

Book leverages `os.UserConfigDir` to determine where to store your bookmarks. [More information on how UserConfigDir determines which directory here](https://pkg.go.dev/os#UserConfigDir)

## Sharing Bookmarks

If you use book to store common bookmarks, but want to share those bookmarks with someone else, you can share the bookmarks.csv file located in your UserConfigDir. The person receiving those bookmarks can add that file to their UserConfigDir, or pick and choose the bookmarks that they'd like to keep and simply add those to their bookmarks.csv
