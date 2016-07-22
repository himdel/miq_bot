module Linter
  class JSCS < Base
    private

    def config_files
      [".jscsrc"]
    end

    def linter_executable
      'jscs *'
    end

    def options
      {:reporter => 'json'}
    end

    def filtered_files(files)
      files.select { |file| file.end_with?(".js") }
    end
  end
end
