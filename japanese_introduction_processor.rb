require './parse_base'

module JapaneseIntroductionProcessor

	BOOK_LIST_NOT_IN_JPN = ['three', 'eight', 'js']
	VERSE_TYPE_OF_INTRODUCTION = 'article'

	def get_book_index(book)
		book_idx = BOOK_LIST_NOT_IN_JPN.index book
		book_idx
	end

	def get_title_info_and_remove(target_content)

		h2_nodes = target_content/'h2'
		title_info = parse_verse(h2_nodes[1], 'title')
		title_name = title_info[:text]
		@log.info("@@ #{title_name} @@")
		h2_nodes.remove

		title_info
	end

	def get_target_content(content, book)
		book_idx = get_book_index book
		content = content/"div[@class='topic']"
		content[book_idx]
	end

	def japanese_introduction_process(content, book)

		target_content = get_target_content content, book

		# タイトルの部分を取得し、削除
		title_info = get_title_info_and_remove target_content

		# 残りの情報を取得
		infos = parse_verses(target_content, VERSE_TYPE_OF_INTRODUCTION)

		# タイトルと残りの情報を結合
		all_infos = [title_info] + infos

		all_infos
	end

end