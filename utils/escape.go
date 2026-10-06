package utils

import "strings"

func Escape(in string) string {
	output := strings.ReplaceAll(in, "&", "&amp;")
	output = strings.ReplaceAll(output, ">", "&gt;")
	output = strings.ReplaceAll(output, "<", "&lt;")
	output = strings.ReplaceAll(output, "\"", "&quot;")
	output = strings.ReplaceAll(output, "'", "&#39;")
	return output
}
