require 'logger'
require './parse_base'

class ReferenceProcessor < ParseBase

	# 最終的に残すタグ（rubyはあとで処理してもらえる）
	ALLOWED_NODE_TYPE = ['text', 'ruby']

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
	end

	def check_if_not_cotains_tag(node)
		if node.children.to_a.any?{|c| !ALLOWED_NODE_TYPE.include? c.name }
			raise "invalid tag found in '#{node.to_html}'"
		end
	end


	def process_ref(ref_node)
		@log.debug("scripture reference found")

		pos = position_count ref_node
		text = ref_node.inner_html
		href = ref_node['href']
		length = text.length

		check_if_not_cotains_tag ref_node

		unwrap ref_node
		
		ref_info = {href: href, pos: pos, length: length, text: text}
	end

end