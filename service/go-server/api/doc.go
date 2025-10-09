package api

import (
	_ "embed"
	"strings"
)

var (
	//go:embed openapi/openapi.yaml
	openAPISpecYAML []byte
	//go:embed swagger.html
	swaggerHTMLTemplate string
)

// OpenAPISpec returns the embedded OpenAPI specification in YAML format.
func OpenAPISpec() []byte {
	return openAPISpecYAML
}

// SwaggerHTML returns the Swagger UI HTML with the provided spec URL injected.
func SwaggerHTML(specURL string) []byte {
	html := strings.ReplaceAll(swaggerHTMLTemplate, "{{SPEC_URL}}", specURL)
	return []byte(html)
}
