require 'logger'
require './parse_base'

class StyleProcessor < ParseBase

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
	end

	def get_style_type(style_node)
		if style_node.name == 'span'
			style_type = style_node['class']
		elsif style_node.name == 'em' || style_node.name == 'b'
			style_type = style_node.name
		else
			raise 'Something wrong: unknown style found'
		end
		style_type
	end

	def process_style(style_node)
		@log.debug("style found")

		style_type = get_style_type style_node

		pos = position_count style_node
		if style_node.children.to_a.any?{|c| c.name != 'text'}
			# 脚注がスタイルの中に含まれている場合（2ne22:2, D&C20:38）
			text = ''
			style_node.children.each do |sub_st_node|
				next if sub_st_node.name == 'sup'
				if sub_st_node.name == 'text'
					text += sub_st_node.content
				else
					text += sub_st_node.inner_html 
				end
			end
		# elsif style_type == 'label' && style_node.child.name ==  'a'
		# 	@log.debug("label found")
		# 	text = style_node.child.inner_html
		else
			text = style_node.inner_html
		end
		text = style_node.inner_html
		length = text.length

		unwrap style_node

		style_info = {type: style_type, pos: pos, length: length, text: text}
	end

end