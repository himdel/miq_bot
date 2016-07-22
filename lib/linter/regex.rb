module Linter
  class Regex < Base
    private

    def config_files
      ['.miq_bot_regex.yml']
    end

    def linter_executable
      nil
    end

    def options
      nil
    end

    def run_linter
      regexes = YAML.load(File.join(@work_dir, config_files.first))
      offences = []

      files = filtered_files
      files.each do |file|
        offences += filter(file, regexes)
      end

      OpenStruct.new(:output => offences,
                     :exit_status => 0,
                     :error => nil)
    end

    def filter(file, regexes)
      # TODO
      [regexes.first]
    end

    def parse_output(identity)
      identity
    end

    def filtered_files(files)
      files
    end
  end
end
