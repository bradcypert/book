package main

import (
	"errors"
	"flag"
	"log/slog"
	"os"
	"strings"

	"github.com/rodaine/table"
)

var logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
	Level:     slog.LevelError,
	AddSource: true,
}))

type Input struct {
	Bookmark  string
	Path      string
	Tags      []string
	Search    bool
	DeleteAll bool
}

func main() {
	input, err := parseFlags()
	if err != nil {
		logger.Error(err.Error())
		return
	}

	if input.DeleteAll {
		handleDelete()
	} else if input.Path != "" {
		handleStore(input)
	} else if input.Search {
		handleSearch(input)
	} else {
		handleOpen(input)
	}
}

func handleDelete() {
	err := DeleteBookmarkFile()
	if err != nil {
		logger.Error(err.Error())
	}
}

func handleStore(input Input) {
	file, err := getBookmarkFile(os.O_APPEND | os.O_WRONLY)
	if err != nil {
		logger.Error(err.Error())
	}
	err = StoreBookmark(file, input.Bookmark, input.Path, input.Tags)
	if err != nil {
		logger.Error(err.Error())
	}
}

func handleSearch(input Input) {
	file, err := getBookmarkFile(os.O_RDONLY)
	if err != nil {
		logger.Error(err.Error())
	}
	items, err := SearchBookmarks(file, input.Bookmark)
	if err != nil {
		logger.Error(err.Error())
	}
	tbl := table.New("Bookmark", "Path", "Tags")
	for _, item := range items {
		tbl.AddRow(item.Value, item.Path, strings.Join(item.Tags, ","))
	}

	tbl.Print()
}

func handleOpen(input Input) {
	file, err := getBookmarkFile(os.O_RDONLY)
	if err != nil {
		logger.Error(err.Error())
	}
	item, err := GetBookmark(file, input.Bookmark)
	if err != nil {
		logger.Error(err.Error())
	}

	err = openExternal(item.Path)
	if err != nil {
		logger.Error(err.Error())
	}

}

func parseFlags() (Input, error) {
	tags := flag.String("tags", "", "Comma Separated tags for faster searching")
	search := flag.Bool("search", false, "Search for existing bookmarks against the provided query")
	deleteAll := flag.Bool("deleteAll", false, "Ignore other flags and delete the bookmark database")
	t := strings.Split(*tags, ",")

	flag.Parse()

	bookmark := flag.Arg(0)
	path := flag.Arg(1)

	if bookmark == "" && !*deleteAll {
		return Input{}, errors.New("a bookmark value is required. This value is the argument directly after the \"book\" command")
	}

	return Input{
		Path:      path,
		Tags:      t,
		Bookmark:  bookmark,
		DeleteAll: *deleteAll,
		Search:    *search,
	}, nil
}
