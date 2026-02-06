package statements

import (
	"fmt"

	// "github.com/pkg/errors"

	"github.com/guided-traffic/gonja/exec"
	"github.com/guided-traffic/gonja/nodes"
	"github.com/guided-traffic/gonja/parser"
	"github.com/guided-traffic/gonja/tokens"
	"github.com/guided-traffic/gonja/utils"
)

type LoremStmt struct {
	Location *tokens.Token
	count    int    // number of paragraphs
	method   string // w = words, p = HTML paragraphs, b = plain-text (default is b)
	random   bool   // does not use the default paragraph "Lorem ipsum dolor sit amet, ..."
}

func (stmt *LoremStmt) Position() *tokens.Token { return stmt.Location }
func (stmt *LoremStmt) String() string {
	t := stmt.Position()
	return fmt.Sprintf("LoremStmt(Line=%d Col=%d)", t.Line, t.Col)
}

func (stmt *LoremStmt) Execute(r *exec.Renderer, tag *nodes.StatementBlock) error {
	lorem, err := utils.Lorem(stmt.count, stmt.method)
	if err != nil {
		return err
	}
	_, _ = r.WriteString(lorem)

	return nil
}

func loremParser(p *parser.Parser, args *parser.Parser) (nodes.Statement, error) {
	stmt := &LoremStmt{
		Location: p.Current(),
		count:    1,
		method:   "b",
	}

	if countToken := args.Match(tokens.Integer); countToken != nil {
		stmt.count = exec.AsValue(countToken.Val).Integer()
	}

	if methodToken := args.Match(tokens.Name); methodToken != nil {
		if methodToken.Val != "w" && methodToken.Val != "p" && methodToken.Val != "b" {
			return nil, args.Error("lorem-method must be either 'w', 'p' or 'b'.", nil)
		}

		stmt.method = methodToken.Val
	}

	if args.MatchName("random") != nil {
		stmt.random = true
	}

	if !args.End() {
		return nil, args.Error("Malformed lorem-tag args.", nil)
	}

	return stmt, nil
}

func init() {
	_ = All.Register("lorem", loremParser)
}
