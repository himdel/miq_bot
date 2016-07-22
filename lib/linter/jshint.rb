module Linter
  class JSHint < Base
    private

    def config_files
      [".jshintrc"]
    end

    def linter_executable
      'jshint *'
    end

    def options
      # needs jshint-json package
      {:reporter => 'json'}
    end

    def filtered_files(files)
      files.select { |file| file.end_with?(".js") }
    end
  end
end
