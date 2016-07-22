module Linter
  class ESLint < Base
    private

    def config_files
      [".eslintrc.js"]
    end

    def linter_executable
      'bin/eslint'
    end

    def options
      {:format => 'json'}
    end

    # convert multiple JSON-by-itself lines into one
    def parse_output(str)
      str.split(/\r?\n/).map do |line|
        JSON.parse(line)
      end.flatten
    end

    def filtered_files(files)
      files.select do |file|
        file.end_with?(".js", ".es6")
      end
    end
  end
end
