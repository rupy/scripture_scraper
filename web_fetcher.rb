
require 'open-uri'
require 'net/http'
require 'uri'

class WebFetcher

	RETRY_TIME = 3
	TITLES = ["bom", 'd_c', 'pog', 'old', 'new']

	def initialize(config)
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG

		@config = config

	end

	def try_and_retry
		# 立て続けにたくさんのデータを取ってきていると、エラーを出すことがある。
		# その場合にはしばらく待って、再度実行する

		retry_count = 0
		resp = nil
		begin
			resp = yield
		rescue => e
			print "retry" if retry_count == 0
			print "."
			sleep(RETRY_TIME * retry_count)
			retry_count += 1
			retry
		end
		puts "" if retry_count > 0
		resp
	end

	def read_url_list(title_id)
		title = TITLES[title_id]
		url_list_dir = @config['structure']['url_list_dir']
		target_file_path = "#{url_list_dir}/#{title}.txt"
		target_urls = open(target_file_path).read.split
		target_urls
	end

	def fetch(url)

		# リダイレクトされているかのチェック
		response = Net::HTTP.get_response(URI.parse(url))
		if response.kind_of? Net::HTTPRedirection
			return nil
		end

		# HTMLデータを取ってくる
		charset = nil
		web_data = try_and_retry do
			open(url) do |f|
				charset = 'utf-8'
				f.read
			end
		end

		web_data
	end

	def mkdir_unless_exist(dir_path)
		Dir.mkdir(dir_path) unless FileTest.exist?(dir_path)
	end

	def prepare_dir(lang = 'eng')

		web_page_dir = @config['structure']['web_page_dir']
		lang_dir_path = "#{web_page_dir}/#{lang}"
		mkdir_unless_exist(lang_dir_path)

		TITLES.each do |title|
			dir_path = sprintf("%s/%s/%s", web_page_dir, lang, title)
			mkdir_unless_exist(dir_path)
		end
	end

	def store(file_name, web_data)
		open(file_name, "wb") do |f|
			f.write(web_data)
		end
	end

	def create_dummy(file_name)
		open(file_name + '.notfound', "wb")
	end


	def get_web_page_file_name(lang, title_id, book_id)
		title = TITLES[title_id]
		web_page_dir = @config['structure']['web_page_dir']
		file_name = sprintf("%s/%s/%s/%03d.html", web_page_dir, lang, title, book_id)
		file_name
	end

	def undownloadable? lang, title
		(lang == 'jpn' && title == 'old') ||
		(lang == 'jpn' && title == 'new')
	end

	def fetch_and_store_web_pages(lang = 'eng', overwrite_flag = false)

		@log.info("start fetch web pages")

		prepare_dir lang

		TITLES.each_with_index do |title, title_id|

			if undownloadable? lang, title
				@log.info("#{lang}, #{title} is not downloadable. skip.")
				next
			end

			target_urls = read_url_list title_id

			# 並列実行
			target_urls.each_with_index do |url, page_id|

				url.sub!('eng', lang)

				@log.info("fetch target: #{lang}, #{title}, #{page_id}")

				file_name = get_web_page_file_name lang, title_id, page_id
				if File.exist?(file_name) && !overwrite_flag
					@log.info("file '#{file_name}' already exists. skip.")
				else
					web_data = fetch url
					if web_data.nil?
						@log.info("this page include redirection. skip.")
						create_dummy file_name
					else
						store file_name, web_data
					end
				end
			end
		end
	end

	def get_book_names(title_id)
		target_urls = read_url_list title_id
		book_names = target_urls.map{|url|url.split(/\//).last.split(/\./)[0]}
		book_names
	end

	def read_web_data(title_id, book_id)
		file_name = get_web_page_file_name title_id, book_id
		web_data = open(file_name, "r") do |f|
			f.read
		end
		web_data
	end

end