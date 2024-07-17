package main

import (
	"fmt"
	"os/exec"
	"regexp"
	"runtime"
)

var urlRegex, err = regexp.Compile("^https?://")

func openExternal(path string) error {
	var err error

	switch runtime.GOOS {
	case "linux":
		err = exec.Command("xdg-open", path).Start()
	case "windows":
		if urlRegex.MatchString(path) {
			err = exec.Command("rundll32", "url.dll,FileProtocolHandler", path).Start()
		} else {
			err = exec.Command("explorer", "/select,", path).Start()
		}

	case "darwin":
		err = exec.Command("open", path).Start()
	default:
		err = fmt.Errorf("unsupported platform")
	}
	if err != nil {
		return err
	}

	return nil

}
