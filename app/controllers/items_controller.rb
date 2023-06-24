class ItemsController < ApplicationController
  before_action :require_user_logged_in

  def show
    @item = Item.find(params[:id])
    @want_users = @item.want_users
    @have_users = @item.have_users
  end

  def new
    @items = []

    @keyword = search_params = params[:keyword]
    @narrow_down = params[:narrow_down]
    @option = params[:option]
    @genreid = params[:genreid]
    @end_of_data = -1
    page_info = { 'prev' => [], 'lowest_price' => 0 }
    case params[:commit]
    when '△ 前に'
      page_info = JSON::parse(current_user.search_result)
      lowest_price = page_info['prev'].pop
      search_params = "#{@keyword},#{lowest_price}円以上" unless lowest_price.nil?
    when '▽ 次に'
      page_info = JSON::parse(current_user.search_result)
      page_info['prev'] << page_info['lowest_price']
      search_params = "#{@keyword},#{page_info['highest_price']+1}円以上"
    when '商品を検索'
      if @narrow_down.present?
        @keyword = search_params = "#{@keyword},#{@narrow_down}#{@option}"
        if @option == '円以上'
          page_info['prev'] = []
          page_info['lowest_price']= @narrow_down.to_i
        else
          page_info = JSON::parse(current_user.search_result)
          search_params = "#{@keyword},#{page_info['lowest_price']}円以上"
        end
      end
    when '同一カテゴリー商品の表示'
      if @genreid
        @keyword = search_params = "#{@keyword},#{@genreid}genreid"
      end
    end

    if @keyword.present?
      search_result = ProductSearch::keyword_search(search_params)
      results = search_result['data']
      @end_of_data = search_result['end_of_data']

      results.each do |result|
        item = Item.find_or_initialize_by(result)
        @items << item
      end
    end

    @narrow_down = nil
    @start_page = page_info['prev'].empty?
    if results && !results.size.zero?
      page_info['lowest_price'] = results.first['price']
      page_info['highest_price'] = @end_of_data
    end

    current_user.search_result = JSON::unparse(page_info)
    current_user.save
  end
end
