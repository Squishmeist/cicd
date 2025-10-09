OPENAPI_DIR := api/openapi
GEN_DIR := api/gen
OAPI := oapi-codegen
PACKAGE := api

OPENAPI_FILES := $(wildcard $(OPENAPI_DIR)/*.yaml)

.PHONY: generate clean

generate: $(OPENAPI_FILES)
	@mkdir -p $(GEN_DIR)
	@if [ -z "$(OPENAPI_FILES)" ]; then \
		echo "No OpenAPI specifications found in $(OPENAPI_DIR)"; \
	else \
		for spec in $(OPENAPI_FILES); do \
			name=$$(basename $$spec .yaml); \
			echo "Generating code for $$spec"; \
			$(OAPI) -generate types -package $(PACKAGE) $$spec > $(GEN_DIR)/$${name}_types.gen.go; \
			$(OAPI) -generate echo-server -package $(PACKAGE) $$spec > $(GEN_DIR)/$${name}_server.gen.go; \
		done; \
	fi

clean:
	@if [ -d "$(GEN_DIR)" ]; then \
		rm -f $(GEN_DIR)/*.gen.go; \
	fi
