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
	Delete    bool
	List      bool
}

func main() {
	input, err := parseFlags()
	if err != nil {
		logger.Error(err.Error())
		return
	}

	if input.DeleteAll {
		handleDeleteAll()
	} else if input.List {
		handleList()
	} else if input.Delete && input.Bookmark != "" {
		handleDelete(input)
	} else if input.Path != "" {
		handleStore(input)
	} else if input.Search {
		handleSearch(input)
	} else {
		handleOpen(input)
	}
}

func handleDeleteAll() {
	err := DeleteBookmarkFile()
	if err != nil {
		logger.Error(err.Error())
	}
}

func handleDelete(input Input) {
	file, err := getBookmarkFile(os.O_APPEND | os.O_RDWR)
	if err != nil {
		logger.Error(err.Error())
	}
	err = DeleteBookmark(file, input.Bookmark)
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

func handleList() {
	file, err := getBookmarkFile(os.O_RDONLY)
	if err != nil {
		logger.Error(err.Error())
	}
	items, err := SearchBookmarks(file, "")
	if err != nil {
		logger.Error(err.Error())
	}
	tbl := table.New("Bookmark", "Path", "Tags")
	for _, item := range items {
		tbl.AddRow(item.Value, item.Path, strings.Join(item.Tags, ","))
	}

	tbl.Print()
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
		return
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
	d := flag.Bool("delete", false, "Delete the bookmark by the provided key")
	l := flag.Bool("list", false, "List all bookmarks")
	t := strings.Split(*tags, ",")

	flag.Parse()

	bookmark := flag.Arg(0)
	path := flag.Arg(1)

	if bookmark == "" && !(*deleteAll || *l) {
		return Input{}, errors.New("a bookmark value is required. This value is the argument directly after the \"book\" command")
	}

	return Input{
		Path:      path,
		Tags:      t,
		Bookmark:  bookmark,
		DeleteAll: *deleteAll,
		Delete:    *d,
		Search:    *search,
		List:      *l,
	}, nil
}
