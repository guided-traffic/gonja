# Gonja

[![Go Reference](https://pkg.go.dev/badge/github.com/guided-traffic/gonja.svg)](https://pkg.go.dev/github.com/guided-traffic/gonja)
[![Go Version](https://img.shields.io/github/go-mod/go-version/guided-traffic/gonja)](https://github.com/guided-traffic/gonja/blob/main/go.mod)
[![Build Status](https://github.com/guided-traffic/gonja/actions/workflows/release.yml/badge.svg)](https://github.com/guided-traffic/gonja/actions/workflows/release.yml)
[![Coverage Status](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/guided-traffic/gonja/main/.github/badges/coverage.json)](https://github.com/guided-traffic/gonja)

This gonja repo is a fork of [`gonja`](https://github.com/noirbizarre/gonja) which is unmaintained since 2020. This fork aims to update all dependencies and keep `gonja` compatible with the latest Go versions. Dependencies updates will be maintained by renovate-bot and rolled out every night after successful tests automatically.

`gonja` is [`pongo2`](https://github.com/flosch/pongo2) fork intended to be aligned on `Jinja` template syntax instead of the `Django` one.

Install/update using `go get` (no dependencies required by `gonja`):
```
go get github.com/guided-traffic/gonja
```

## First impression of a template

```HTML+Django
<html><head><title>Our admins and users</title></head>
{# This is a short example to give you a quick overview of gonja's syntax. #}

{% macro user_details(user, is_admin=false) %}
	<div class="user_item">
		<!-- Let's indicate a user's good karma -->
		<h2 {% if (user.karma >= 40) || (user.karma > calc_avg_karma(userlist)+5) %}
			class="karma-good"{% endif %}>
			
			<!-- This will call user.String() automatically if available: -->
			{{ user }}
		</h2>

		<!-- Will print a human-readable time duration like "3 weeks ago" -->
		<p>This user registered {{ user.register_date|naturaltime }}.</p>
		
		<!-- Let's allow the users to write down their biography using markdown;
		     we will only show the first 15 words as a preview -->
		<p>The user's biography:</p>
		<p>{{ user.biography|markdown|truncatewords_html:15 }}
			<a href="/user/{{ user.id }}/">read more</a></p>
		
		{% if is_admin %}<p>This user is an admin!</p>{% endif %}
	</div>
{% endmacro %}

<body>
	<!-- Make use of the macro defined above to avoid repetitive HTML code
	     since we want to use the same code for admins AND members -->
	
	<h1>Our admins</h1>
	{% for admin in adminlist %}
		{{ user_details(admin, true) }}
	{% endfor %}
	
	<h1>Our members</h1>
	{% for user in userlist %}
		{{ user_details(user) }}
	{% endfor %}
</body>
</html>
```

# Documentation

For a documentation on how the templating language works you can [head over to the Jinja documentation](https://jinja.palletsprojects.com). gonja aims to be compatible with it.

You can access gonja's API documentation on [pkg.go.dev](https://pkg.go.dev/github.com/guided-traffic/gonja).

## Caveats 

### Filters

 * **format**: `format` does **not** take Python's string format syntax as a parameter, instead it takes Go's. Essentially `{{ 3.14|stringformat:"pi is %.2f" }}` is `fmt.Sprintf("pi is %.2f", 3.14)`.
 * **escape** / **force_escape**: Unlike Jinja's behaviour, the `escape`-filter is applied immediately. Therefore there is no need for a `force_escape`-filter yet.

# API-usage examples

Please see the documentation for a full list of provided API methods.

## A tiny example (template string)

```Go
// Compile the template first (i. e. creating the AST)
tpl, err := gonja.FromString("Hello {{ name|capfirst }}!")
if err != nil {
	panic(err)
}
// Now you can render the template with the given 
// gonja.Context how often you want to.
out, err := tpl.Execute(gonja.Context{"name": "axel"})
if err != nil {
	panic(err)
}
fmt.Println(out) // Output: Hello Axel!
```

## Example server-usage (template file)

```Go
package main

import (
	"github.com/guided-traffic/gonja"
	"net/http"
)

// Pre-compiling the templates at application startup using the
// little Must()-helper function (Must() will panic if FromFile()
// or FromString() will return with an error - that's it).
// It's faster to pre-compile it anywhere at startup and only
// execute the template later.
var tpl = gonja.Must(gonja.FromFile("example.html"))

func examplePage(w http.ResponseWriter, r *http.Request) {
	// Execute the template per HTTP request
	out, err := tpl.Execute(gonja.Context{"query": r.FormValue("query")})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	w.WriteString(out)
}

func main() {
	http.HandleFunc("/", examplePage)
	http.ListenAndServe(":8080", nil)
}
```

# Benchmark

All benchmarks are compiling (depends on the benchmark) and executing the `testData/complex.tpl` template using:

    go test -bench . -cpu 1,2,4,8 -tags bench -benchmem

| Benchmark | i7-2600 · ns/op | M1 Ultra · ns/op | Speedup |
|---|--:|--:|--:|
| FromCache | 41,259 | 22,693 | 1.8× |
| FromCache-2 | 42,776 | 19,183 | 2.2× |
| FromCache-4 | 44,432 | 19,378 | 2.3× |
| FromCache-8 | — | 19,576 | — |
| FromFile | 437,755 | 285,804 | 1.5× |
| FromFile-2 | 472,828 | 316,581 | 1.5× |
| FromFile-4 | 519,758 | 333,336 | 1.6× |
| FromFile-8 | — | 351,705 | — |
| Execute | 41,984 | 23,474 | 1.8× |
| Execute-2 | 48,546 | 19,488 | 2.5× |
| Execute-4 | 104,469 | 19,750 | 5.3× |
| Execute-8 | — | 19,968 | — |
| CompileAndExecute | 428,425 | 263,730 | 1.6× |
| CompileAndExecute-2 | 459,058 | 281,432 | 1.6× |
| CompileAndExecute-4 | 488,519 | 301,848 | 1.6× |
| CompileAndExecute-8 | — | 309,676 | — |
| ParallelExecute | 45,262 | 23,520 | 1.9× |
| ParallelExecute-2 | 23,490 | 13,984 | 1.7× |
| ParallelExecute-4 | 24,206 | 9,261 | 2.6× |
| ParallelExecute-8 | — | 15,123 | — |

*i7-2600 benchmarked on August 18th 2019 · M1 Ultra benchmarked on February 6th 2026.*
