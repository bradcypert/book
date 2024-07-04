# Book

Book is a simple program for managing and opening bookmarks in your terminal. The aim is to essentially be "go links" but for your terminal and local to your machine.

Book is backed by a CSV file, making it extremely easy to share bookmarks or manipulate your bookmarks with your own programs as well.

```bash
# Add a new bookmark "gh" pointing to github.com
book gh https://www.github.com

# Open the "gh" bookmark
book gh
```

## Deleting a bookmark by the bookmark key

Coming soon.

## Deleting all bookmarks

```bash
book --deleteAll
```

There is no confirmation for this action.

## Searching for bookmarks
```bash
# Search all bookmarks for the word "github" in the bookmark value, path, or tag
book -search github
```

## Where are my bookmarks, though?

Book leverages `os.UserConfigDir` to determine where to store your bookmarks. [More information on how UserConfigDir determines which directory here](https://pkg.go.dev/os#UserConfigDir)

## Sharing Bookmarks

If you use book to store common bookmarks, but want to share those bookmarks with someone else, you can share the bookmarks.csv file located in your UserConfigDir. The person receiving those bookmarks can add that file to their UserConfigDir, or pick and choose the bookmarks that they'd like to keep and simply add those to their bookmarks.csv
