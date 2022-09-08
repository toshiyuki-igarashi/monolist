module ItemsHelper
  def html2text(text)
    if text
      text.gsub(/<BR>/,' ').gsub(/<br>/,' ').gsub(/&nbsp;/,' ').gsub(/&ensp;/,'  ').gsub(/&emsp;/,'  ').gsub(/&thinsp;/,' ')
    else
      ''
    end
  end

  def select_page_text(item)
    if item.code[0] == 'Y'
      'Yahoo!詳細ページ'
    else
      '楽天詳細ページ'
    end
  end

end
