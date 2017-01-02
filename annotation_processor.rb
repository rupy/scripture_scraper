require './ruby_processor'
require './reference_processor'
require './style_processor'
require './footnote_processor'


class AnnotationProcessor < ParseBase
	def initialize
		super
	end

	def process_annotations(verse_node)

		footnote_infos = []
		style_infos = []
		ref_infos = []
		begin
			redo_flag = false # 初めfalseにしておかなけれannotationが一切見つからなかった時に無限ループになる
			annotation_nodes = verse_node.xpath("./*[((name()='b')or(name()='span')or(name()='em')or(name()='sup')or(name()='ruby')or((name()='a')))]") # この書き方でないと順番がめちゃくちゃになる
			annotation_nodes.each do |annotation_node|

				# 子供が複数見つかった時にはタグが入れ子になっているのであとでやり直さなければいけない
				# 子供が一つでも子供がtextノード出ない場合は入れ子になっている（歴代史下17:4で登場）
				# xpathによるタグの取得自体からやり直す理由はswapによってannotation_nodeの中身が空っぽになってしまうため処理が施せないことによる
				redo_flag = annotation_node.children.length > 1
				redo_flag |= check_children_contain_tag annotation_node

				if annotation_node.name == 'em' || annotation_node.name == 'span' || annotation_node.name == 'b'
					# 文字修飾関係の処理
					sp = StyleProcessor.new
					style_info = sp.process_style annotation_node
					style_infos.push style_info
				elsif annotation_node.name == 'sup' && annotation_node['class'] == 'studyNoteMarker'

					# footnoteの中にタグが含まれている
					anchor_node = annotation_node.next_sibling
					anchor_node = annotation_node.previous_sibling if anchor_node.nil?
					raise 'invalid footnote found' if anchor_node.nil?
					redo_flag |= anchor_node.children.length != 1
					redo_flag |= anchor_node.children.to_a.any?{|c| c.name != 'text'}
					# 脚注の処理
					fp = FootnoteProcessor.new
					footnote_info = fp.process_footnote annotation_node
					footnote_infos.push footnote_info
				elsif annotation_node.name == 'a' && annotation_node['class'] == 'scriptureRef'
					# 聖文中で他の聖文が引用されている部分のリンクの処理
					rp = ReferenceProcessor.new
					ref_info = rp.process_ref annotation_node
					ref_infos.push ref_info
				elsif annotation_node.name == 'a' && annotation_node['href'] == '#note' && annotation_node['class'] != 'footnote'
					# ジョセフ・スミス歴史で出てくるnoteの処理	
					rp = ReferenceProcessor.new
					ref_info = rp.process_ref annotation_node
					ref_infos.push ref_info
				elsif annotation_node.name == 'a' && annotation_node['href'] == '#note' && annotation_node['class'] == 'footnote' && annotation_node.inner_text == ''
					# 英語の雅歌で出てくる空っぽのノード
					unwrap annotation_node
				elsif annotation_node.name == 'a' && annotation_node['class'] == 'footnote'
					# マラキの終わりにある特殊な脚注
					next
				elsif annotation_node.name == 'a' && annotation_node['href'].start_with?('https')
					# 教義と聖約の序文のリンク	
					rp = ReferenceProcessor.new
					ref_info = rp.process_ref annotation_node
					ref_infos.push ref_info
				elsif annotation_node.name == 'ruby'
					if annotation_node.children.length == 1 && annotation_node.child.name == 'text' # 1ne1:19でrubyタグが分離している部分がある
						if annotation_node.next_sibling.name == 'ruby'
							@log.debug('split ruby found')
							annotation_node.next_sibling.child.add_previous_sibling annotation_node.child
							parent = annotation_node.parent
							annotation_node.remove
							puts parent.to_html
							next
						else
							raise 'invalid ruby found'
						end
					end
					rp = RubyProcessor.new
					rp.ruby_process annotation_node
				else
					raise 'Unknown annotation found'
				end

				if redo_flag
					print '+'
					# @log.debug("#{verse_node.to_html}")
					break
				end
			end
		end while redo_flag

		return [footnote_infos, style_infos, ref_infos]
	end
end