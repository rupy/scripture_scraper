require 'logger'

class RubyProcessorByText

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
	end

	def ruby_process(text)

		@log.debug('processing ruby by text')

		kanji_regrex_str = '[^一二三四五六七八九十百千万億兆〇\p{Hiragana}\p{Katakana}\w、。「」（）\-・……『』ー ]'
		ruby_regrex = /(#{kanji_regrex_str}+)\((\p{Hiragana}+)\)/

		no_furigana_str = ''

		offset = 0
		while pos = text.index(ruby_regrex, offset)

			kanji_str = $1
			furigana_str = $2

			no_furigana_str += text[offset...(pos + kanji_str.length)]
			offset = pos + $&.length

		end
		no_furigana_str + text[offset..text.length]
	end

end