# frozen_string_literal: true

require 'net/https'
require 'uri'
require 'cgi'
require 'json'

# search product of Rakuten/Yahoo! Shop
module ProductSearch
  module_function

  MAX_TRY = 2
  WAIT_TIME = 0.1
  PAGE_SIZE = 3

  def page_search(page_info, params)
    page = "#{page_info['page']}&#{page_info['id']}=#{ENV[page_info['env_id']]}"
    params.each do |key, param|
      if page_info.key?(key)
        param = CGI.escape(param)
        page = "#{page}&#{page_info[key]}=#{param}"
      end
    end
    page
  end

  def fetch_products_list(page_info, params)
    sleep(WAIT_TIME)
    page = page_search(page_info, params)
    uri = URI.parse(page_info['url'] + page)
    Net::HTTP.get_response(uri)
  end

  def products_list(page_info, params)
    response = fetch_products_list(page_info, params)
    if response.code != '200'
      1.upto(MAX_TRY) do
        response = fetch_products_list(page_info, params)
        break if response.code == '200'
      end
    end
    CGI.unescape(response.body)
  end

  def code_conversion(shop_mall, code, item)
    case code[0]
    when 'code'
      "#{shop_mall}#{item[code[1]]}"
    when 'price', 'image_url', 'genre'
      code[1].call(item)
    else
      item[code[1]]
    end
  end

  def extract_info(shop_mall, codes_list, item)
    result = {}
    codes_list.each do |code|
      result[code[0]] = code_conversion(shop_mall, code, item)
    end
    result
  end

  def parse(body, shop_mall, key, codes_list, item_elm)
    result = []
    items = JSON::Parser.new(body).parse
    if items && items[key]
      items[key].each do |item|
        result << extract_info(shop_mall, codes_list, item_elm.call(item))
      end
    end
    result
  end

  def last_price(data)
    if data.size.zero?
      -1
    else
      data.last['price']
    end
  end

  def keyword_search_page(page_info, search_parms, parse_func, page)
    search_parms['start'] = (page * search_parms['count_step'] + 1).to_s
    list = parse_func.call(products_list(page_info, search_parms))
    { 'end_of_data' => last_price(list), 'data' => select_items(list, search_parms) }
  end

  def set_search_result(result, result_of_page, page)
    result['data'] += result_of_page['data']
    result['page'] = page if result_of_page['data'].size.zero?
    result['next'] = page + 1
    result['end_of_data'] = result_of_page['end_of_data']
    result
  end

  def keyword_search_mkt(page_info, search_parms, parse_func)
    result = { 'page' => search_parms['current'],
               'next' => search_parms['current'] + 1,
               'data' => [],
               'end_of_data' => -1 }
    search_parms['current'].upto(search_parms['max_page']) do |i|
      result_of_page = keyword_search_page(page_info, search_parms, parse_func, i)
      result = set_search_result(result, result_of_page, i)
      break if result_of_page['end_of_data'].negative? || result['data'].size >= PAGE_SIZE
    end
    result
  end

  RAKUTEN_BY_KEYWORD = {
    'url' => 'https://app.rakuten.co.jp',
    'page' => '/services/api/IchibaItem/Search/20170706?sort=%2BitemPrice',
    'id' => 'applicationId',
    'key' => 'keyword',
    'env_id' => 'RAKUTEN_APPLICATION_ID',
    'price_from' => 'minPrice',
    'price_to' => 'maxPrice',
    'start' => 'page'
  }.freeze

  RAKUTEN_BY_ITEM = {
    'url' => 'https://app.rakuten.co.jp',
    'page' => '/services/api/IchibaItem/Search/20170706?sort=%2BitemPrice',
    'id' => 'applicationId',
    'key' => 'itemCode',
    'env_id' => 'RAKUTEN_APPLICATION_ID'
  }.freeze

  RAKUTEN_ITEMDEF = [
    %w[name itemName],
    %w[url itemUrl],
    %w[catch_cpy catchcopy],
    %w[caption itemCaption],
    %w[code itemCode],
    ['price', ->(item) { item['itemPrice'] }],
    ['image_url', ->(item) { item['mediumImageUrls'][0]['imageUrl'] if exist_image_rakuten?(item) }],
    ['genre', ->(item) { "R#{item['genreId']}" }]
  ].freeze

  def exist_image_rakuten?(item)
    if item.nil? || item['mediumImageUrls'].nil? || item['mediumImageUrls'][0].nil?
      false
    else
      true
    end
  end

  def keyword_search_rakuten(search_parms)
    parse_func = proc { |body| parse(body, 'R', 'Items', RAKUTEN_ITEMDEF, ->(item) { item['Item'] }) }
    search_parms['max_page'] = 99
    search_parms['count_step'] = 1
    keyword_search_mkt(RAKUTEN_BY_KEYWORD, search_parms, parse_func)
  end

  def code_search_rakuten(code)
    parse(products_list(RAKUTEN_BY_ITEM, code), 'R', 'Items', RAKUTEN_ITEMDEF, ->(item) { item['Item'] })[0]
  end

  YAHOO_BY_KEYWORD = {
    'url' => 'https://shopping.yahooapis.jp',
    'page' => '/ShoppingWebService/V3/itemSearch?sort=%2Bprice&results=30',
    'id' => 'appid',
    'key' => 'query',
    'env_id' => 'YAHOO_CLIENT_ID',
    'price_from' => 'price_from',
    'price_to' => 'price_to',
    'start' => 'start'
  }.freeze

  YAHOO_ITEMDEF_KEYWORD = [
    %w[name name],
    %w[url url],
    %w[catch_cpy headLine],
    %w[caption description],
    %w[code code],
    ['price', ->(item) { item['price'] }],
    ['image_url', ->(item) { item['image']['medium'] }],
    ['genre', ->(item) { "Y#{item['genreCategory']['id']}" }]
  ].freeze

  def keyword_search_yahoo(search_parms)
    parse_func = proc { |body| parse(body, 'Y', 'hits', YAHOO_ITEMDEF_KEYWORD, ->(item) { item }) }
    search_parms['max_page'] = 33
    search_parms['count_step'] = 30
    keyword_search_mkt(YAHOO_BY_KEYWORD, search_parms, parse_func)
  end

  YAHOO_BY_CODE = {
    'url' => 'https://shopping.yahooapis.jp',
    'page' => '/ShoppingWebService/V1/json/itemLookup?responsegroup=medium',
    'id' => 'appid',
    'key' => 'itemcode',
    'env_id' => 'YAHOO_CLIENT_ID'
  }.freeze

  YAHOO_ITEMDEF_CODE = [
    %w[name Name],
    %w[url Url],
    %w[catch_cpy Headline],
    %w[caption Description],
    %w[code Code],
    ['price', ->(item) { item['Price']['_value'] }],
    ['image_url', ->(item) { item['Image']['Medium'] }],
    ['genre', ->(_item) { 'Y' }]
  ].freeze

  def parse_yahoo_code(body)
    extract_info('Y', YAHOO_ITEMDEF_CODE, JSON::Parser.new(body).parse['ResultSet']['0']['Result']['0'])
  end

  def code_search_yahoo(code)
    parse_yahoo_code(products_list(YAHOO_BY_CODE, code))
  end

  def analyze_keyword(item, keyword)
    case item
    when /円以上$/
      keyword['price_from'] = item.sub(/円以上$/, '')
    when /円以下$/
      keyword['price_to'] = item.sub(/円以下$/, '')
    when /含む$/
      keyword['include_words'] << item.sub(/含む$/, '')
    when /含まない$/
      keyword['exclude_words'] << item.sub(/含まない$/, '')
    when /page$/
      keyword['current'] = item.sub(/page$/, '').to_i
    else
      keyword['key'] = item
    end
    keyword
  end

  def parse_keywords(keywords)
    items = keywords.split(',')
    search_parms = { 'key' => '', 'include_words' => [], 'exclude_words' => [], 'current' => 0 }
    items.each do |item|
      search_parms = analyze_keyword(item, search_parms)
    end
    search_parms
  end

  def include_word?(explanation, word)
    return false if explanation.nil?

    explanation[word]
  end

  def including_some_words?(item, word_list)
    word_list.each do |word|
      return true if include_word?(item['name'], word) ||
                     include_word?(item['catch_cpy'], word) ||
                     include_word?(item['caption'], word)
    end
    false
  end

  def including_all_words?(item, word_list)
    word_list.each do |word|
      return false unless include_word?(item['name'], word) ||
                          include_word?(item['catch_cpy'], word) ||
                          include_word?(item['caption'], word)
    end
    true
  end

  def should_include?(item, search_parms)
    return false if search_parms.key?('price_from') && item['price'] < search_parms['price_from'].to_i
    return false if search_parms.key?('price_to') && item['price'] > search_parms['price_to'].to_i

    including_all_words?(item, search_parms['include_words']) &&
      !including_some_words?(item, search_parms['exclude_words'])
  end

  def select_items(list, search_parms)
    result = []
    list.each do |item|
      result << item if should_include?(item, search_parms)
    end
    result
  end

  def narrow_down_search(database, keywords)
    search_parms = parse_keywords(keywords)
    list = JSON.parse(database)
    select_items(list, search_parms).sort do |a, b|
      a['price'] <=> b['price']
    end
  end

  def end_of_data(rakuten, yahoo)
    if rakuten['end_of_data'].negative?
      yahoo['end_of_data']
    elsif yahoo['end_of_data'].negative?
      rakuten['end_of_data']
    else
      [rakuten['end_of_data'], yahoo['end_of_data']].max
    end
  end

  def keyword_search_result(rakuten, yahoo)
    { 'data' => (rakuten['data'] + yahoo['data']).sort { |a, b| a['price'].to_i <=> b['price'].to_i },
      'page' => [rakuten['page'], yahoo['page']].min,
      'next' => [rakuten['next'], yahoo['next']].min,
      'end_of_data' => end_of_data(rakuten, yahoo) }
  end

  def keyword_search(keywords)
    search_parms = parse_keywords(keywords)
    rakuten = keyword_search_rakuten(search_parms)
    yahoo = keyword_search_yahoo(search_parms)
    keyword_search_result(rakuten, yahoo)
  end

  def code_search(code)
    host_mkt = code[0]
    code = code[1, code.size - 1]
    case host_mkt
    when 'R'
      code_search_rakuten({ 'key' => code })
    when 'Y'
      code_search_yahoo({ 'key' => code })
    else
      []
    end
  end
end
