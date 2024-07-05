package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
)

type Bookmark struct {
	Value string
	Path  string
	Tags  []string
}

// TODO: Handle duplicates?
func StoreBookmark(writer io.Writer, bookmark string, path string, tags []string) error {
	_, err := writer.Write([]byte(fmt.Sprintf("%s,%s,%v\n", bookmark, path, tags)))

	if err != nil {
		return err
	}

	return nil
}

// DeleteBookmark deletes a bookmark from the bookmark database using the bookmark's key
func DeleteBookmark(reader io.Reader, bookmark string) error {
	fp, err := getBookmarkFilePath()

	var bs []byte
	buf := bytes.NewBuffer(bs)

	scanner := bufio.NewScanner(reader)
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
func SearchBookmarks(reader io.Reader, query string) ([]Bookmark, error) {
	var searchResults []Bookmark

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		if strings.Contains(scanner.Text(), fmt.Sprintf("%s", query)) {
			values := strings.Split(string(scanner.Bytes()), ",")
			b := Bookmark{
				Value: values[0],
				Path:  values[1],
				Tags:  values[2:],
			}
			searchResults = append(searchResults, b)
		}
	}
	if err := scanner.Err(); err != nil {
		return searchResults, err
	}

	return searchResults, nil
}

// GetBookmark
// gets the bookmark data that matches the provided bookmark key
func GetBookmark(reader io.Reader, bookmark string) (Bookmark, error) {
	scanner := bufio.NewScanner(reader)
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
