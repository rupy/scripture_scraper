require 'yaml'
require 'csv'
require 'logger'

class InfoWriter

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG

		@config = YAML.load_file('config/config.yml')
		@output_csv_dir = @config['structure']['output_csv_dir']
	end

	def write_scripture_info(all_infos)
		output_csv_file = "#{@output_csv_dir}/scripture.csv"
		CSV.open(output_csv_file, 'w') do |writer|
			id = 0
			all_infos.each_with_index do |book_infos, title_id|
				book_infos.each_with_index do |infos, book_id|
					infos[:infos].each_with_index do |info, chapter_id|
						writer << [id, title_id, book_id, chapter_id, infos[:title], infos[:book], infos[:chapter], info[:verse_name], info[:verse_num], info[:type], info[:text]]
						id += 1
					end
				end
			end
		end
	end

	def write_footnote_info(all_infos)
		footnote_csv_file = "#{@output_csv_dir}/footnotes.csv"
		fn_ref_csv_file = "#{@output_csv_dir}/footnote_references.csv"
		fn_st_csv_file = "#{@output_csv_dir}/footnote_styles.csv"
		CSV.open(footnote_csv_file, 'w') do |writer|
		CSV.open(fn_ref_csv_file, 'w') do |writer_fn_ref|
		CSV.open(fn_st_csv_file, 'w') do |writer_fn_st|
			id = 0
			fn_id = 0
			fn_rf_id = 0
			fn_st_id = 0
			all_infos.each_with_index do |book_infos, title_id|
				book_infos.each_with_index do |infos, book_id|
					infos[:infos].each_with_index do |info, chapter_id|
						fn_infos = info[:footnote_infos]
						unless fn_infos.nil? || fn_infos.empty?
							fn_infos.each_with_index do |fn_info, verse_id|
								writer << [fn_id, id, book_id, chapter_id, verse_id, infos[:title], infos[:book], infos[:chapter], fn_info[:marker], fn_info[:href], fn_info[:rel], fn_info[:footnote], fn_info[:pos], fn_info[:length], fn_info[:text]]
								fn_info[:fn_ref_infos].each do |fn_ref_info|
									writer_fn_ref << [fn_rf_id, fn_id, id, title_id, book_id, chapter_id, verse_id, infos[:title], infos[:book], infos[:chapter], fn_info[:marker], fn_info[:footnote], fn_info[:text], fn_ref_info[:rel], fn_ref_info[:pos], fn_ref_info[:length], fn_ref_info[:text]]
									fn_rf_id += 1
								end
								fn_info[:fn_st_infos].each do |fn_st_info|
									writer_fn_st << [fn_st_id, fn_id, id, title_id, book_id, chapter_id, verse_id, infos[:title], infos[:book], infos[:chapter], fn_info[:marker], fn_info[:footnote], fn_info[:text], fn_st_info[:type], fn_st_info[:pos], fn_st_info[:length], fn_st_info[:text]]
									fn_st_id += 1
								end
								fn_id += 1
							end
						end
						id += 1
					end
				end
			end
		end
		end
		end
	end

	def write_style_info(all_infos)
		style_csv_file = "#{@output_csv_dir}/styles.csv"
		CSV.open(style_csv_file, 'w') do |writer|
			id = 0
			st_id = 0
			all_infos.each_with_index do |book_infos, title_id|
				book_infos.each_with_index do |infos, book_id|
					infos[:infos].each_with_index do |info, chapter_id|
						st_infos = info[:style_infos]
						unless st_infos.nil? || st_infos.empty?
							st_infos.each do |st_info|
								writer << [st_id, id, title_id, book_id, chapter_id, infos[:title], infos[:book], infos[:chapter], st_info[:type], st_info[:pos], st_info[:length], st_info[:text]]
								st_id += 1
							end
						end
						id += 1
					end
				end
			end
		end
	end

	def write_reference_info(all_infos)
		ref_csv_file = "#{@output_csv_dir}/references.csv"
		CSV.open(ref_csv_file, 'w') do |writer|
			id = 0
			rf_id = 0
			all_infos.each_with_index do |book_infos, title_id|
				book_infos.each_with_index do |infos, book_id|
					infos[:infos].each_with_index do |info, chapter_id|
						rf_infos = info[:ref_infos]
						unless rf_infos.nil? || rf_infos.empty?
							rf_infos.each do |rf_info|
								writer << [rf_id, id, title_id, book_id, chapter_id, infos[:title], infos[:book], infos[:chapter], rf_info[:href], rf_info[:pos], rf_info[:length], rf_info[:text]]
								rf_id += 1
							end
						end
					end
					id += 1
				end
			end
		end
	end

	def write_infos_to_csv(all_infos)


		@log.info("writing csv files")

		write_scripture_info all_infos 
		write_footnote_info all_infos
		write_style_info all_infos
		write_reference_info all_infos


	end
end