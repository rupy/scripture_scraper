require 'open-uri'
require 'net/http'
require 'uri'
require 'fileutils'
require './web_fetcher'

class FootnoteWebFetcher < WebFetcher

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG

		@config = YAML.load_file('config/config.yml')
	end

	def mkdir_p_unless_exist(dir_path)
		FileUtils.mkdir_p dir_path unless FileTest.exist?(dir_path)
	end

	def create_web_footnote_dir_path_and_file_name(url)
		web_page_dir = @config['structure']['web_footnote_dir']

		uri = URI::parse(url)
		q_array = URI::decode_www_form(uri.query)
		q_hash = Hash[q_array]

		footnote_dir_path = "#{web_page_dir}/#{q_hash['lang']}/#{q_hash['volumeUri']}/#{q_hash['bookUri']}/#{q_hash['chapterUri']}/"
		file_name = "#{q_hash['noteID']}.html"
		[footnote_dir_path, file_name]
	end

	def fetch_and_store(url, overwrite_flag = false)

		dir_path, file_name = create_web_footnote_dir_path_and_file_name url
		file_path = dir_path + file_name

		if File.exist?(file_path) && !overwrite_flag
			# @log.info("file '#{file_path}' already exists. skip.")
		else
			@log.info("write footnote: #{file_path}")

			mkdir_p_unless_exist dir_path
			web_data = fetch url
			store file_path, web_data
		end
	end

	def read_footnote_data(url)
		dir_path, file_name = create_web_footnote_dir_path_and_file_name url
		file_path = dir_path + file_name
		if File.exist?(file_path)
			web_data = open(file_path, "r") do |f|
				f.read
			end
			web_data
		else
			nil
		end
	end

end