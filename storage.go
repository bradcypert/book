package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"os"
	"path"
	"strings"
)

type Bookmark struct {
	Value string
	Path  string
	Tags  []string
}

func getStoragePath() (string, error) {
	p, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}

	fp := path.Join(p, "bradcypert")
	return fp, nil
}

func getBookmarkFilePath() (string, error) {
	s, err := getStoragePath()
	if err != nil {
		return "", err
	}

	p := path.Join(s, "bookmarks.csv")
	return p, nil
}

func DeleteBookmarkFile() error {
	p, err := getBookmarkFilePath()
	if err != nil {
		return err
	}
	return os.Remove(p)
}

func getBookmarkFile(fileMode int) (*os.File, error) {
	p, err := getBookmarkFilePath()
	if err != nil {
		return nil, err
	}

	sp, err := getStoragePath()
	if err != nil {
		return nil, err
	}

	os.MkdirAll(sp, os.ModePerm)

	if _, err := os.Stat(p); errors.Is(err, os.ErrNotExist) {
		file, err := os.Create(p)
		if err != nil {
			return nil, err
		}

		return file, nil
	}

	// if it exists, just open it
	file, err := os.OpenFile(p, fileMode, os.ModeAppend)
	if err != nil {
		return nil, err
	}

	return file, nil
}

// TODO: Handle duplicates?
func StoreBookmark(bookmark string, path string, tags []string) error {
	file, err := getBookmarkFile(os.O_APPEND | os.O_WRONLY)
	defer file.Close()
	if err != nil {
		return err
	}

	_, err = file.WriteString(fmt.Sprintf("%s,%s,%v\n", bookmark, path, tags))

	if err != nil {
		return err
	}

	return nil
}

// DeleteBookmark deletes a bookmark from the bookmark database using the bookmark's key
func DeleteBookmark(bookmark string) error {
	fp, err := getBookmarkFilePath()
	file, err := getBookmarkFile(os.O_APPEND | os.O_RDWR)
	defer file.Close()

	var bs []byte
	buf := bytes.NewBuffer(bs)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if !strings.HasPrefix(scanner.Text(), fmt.Sprintf("%s,", bookmark)) {
			_, err := buf.Write(scanner.Bytes())
			if err != nil {
				return err
			}
			_, err = buf.WriteString("\n")
			if err != nil {
				return err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}

	err = os.WriteFile(fp, buf.Bytes(), 0666)
	if err != nil {
		return err
	}

	return nil
}

// SearchBookmarks searches the bookmark "database" for any potential match against
// the provided query. It searches the bookmark name, path value, and the tags for a match
// and returns a slice of the raw text matching against the query provided.
func SearchBookmarks(query string) ([]Bookmark, error) {
	file, err := getBookmarkFile(os.O_RDONLY)
	defer file.Close()

	var searchResults []Bookmark

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if !strings.Contains(scanner.Text(), fmt.Sprintf("%s", query)) {
			values := strings.Split(string(scanner.Bytes()), ",")
			b := Bookmark{
				Value: values[0],
				Path:  values[1],
				Tags:  values[2:],
			}
			searchResults = append(searchResults, b)
			if err != nil {
				return searchResults, err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return searchResults, err
	}

	return searchResults, err
}

// GetBookmark
// gets the bookmark data that matches the provided bookmark key
func GetBookmark(bookmark string) (Bookmark, error) {
	file, err := getBookmarkFile(os.O_RDONLY)
	if err != nil {
		return Bookmark{}, err
	}

	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if strings.HasPrefix(scanner.Text(), bookmark) {
			values := strings.Split(string(scanner.Bytes()), ",")
			b := Bookmark{
				Value: values[0],
				Path:  values[1],
				Tags:  values[2:],
			}
			return b, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return Bookmark{}, err
	}

	return Bookmark{}, errors.New("bookmark not found")
}
