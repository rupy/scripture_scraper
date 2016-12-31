require 'logger'

class FootnoteReferenceProcessor < ParseBase

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG

	end

	def process_fn_ref(ref_node)
		@log.debug("footnote reference found")
		pos = position_count ref_node
		text = ref_node.inner_html
		if ref_node.children.to_a.any?{|c| c.name != 'text'}
			# raise "non-text node found in #{ref_node.to_html}"
			text = ref_node.content
		end
		unwrap ref_node
		rel = ref_node['rel']
		length = text.length

		fn_ref_info = {rel: rel, pos: pos, length: length, text: text}
	end
end