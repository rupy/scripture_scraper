
require 'open-uri'

class WebFetcher

	RETRY_TIME = 3
	TITLES = ["old", 'new']

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

	def store(file_name, web_data)
		open(file_name, "wb") do |f|
			f.write(web_data)
		end
	end

	def get_web_page_file_name(title_id, book_id)
		title = TITLES[title_id]
		web_page_dir = @config['structure']['web_page_dir']
		file_name = sprintf("#{web_page_dir}/%s/%02d.xml", title, book_id)
		file_name
	end

	def fetch_and_store_web_pages(overwrite_flag = false)

		@log.info("start fetch web pages")

		TITLES.each_with_index do |title, title_id|

			target_urls = read_url_list title_id
			target_urls.each_with_index do |url, book_id|

				@log.info("fetch target: #{title}, #{book_id}")

				file_name = get_web_page_file_name title_id, book_id
				if File.exist?(file_name) && !overwrite_flag
					@log.info("file '#{file_name}' already exists. skip.")
				else
					web_data = fetch url
					store file_name, web_data
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