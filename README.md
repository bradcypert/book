# Book

Book is a simple program for managing and opening bookmarks in your terminal. The aim is to essentially be "go links" but for your terminal and local to your machine.

Book is backed by a CSV file, making it extremely easy to share bookmarks or manipulate your bookmarks with your own programs as well.

```bash
# Add a new bookmark "gh" pointing to github.com
book -path=https://www.github.com gh

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


