require 'sinatra'
require 'haml'
require 'pry'
require 'RMagick'
require 'typhoeus'

include Magick

get '/' do
  haml :index
end

url_regexp = /(?<prefix>^http:\/\/[\.\w]+\/\w+\/\d+\/)(?<y>\d+)\/(?<x>\d+)(?<extension>.+$)/

post '/image' do
  rows = params[:x_count].to_i
  columns = params[:y_count].to_i

  matches = url_regexp.match(params[:image_url])
  url_prefix = matches[:prefix]
  url_extension = matches[:extension]
  x_pos = matches[:x].to_i
  y_pos = matches[:y].to_i

  blob_grid = Array.new(columns + 1).map { Array.new(rows + 1) }
  hydra = Typhoeus::Hydra.new

  (x_pos..(x_pos + rows)).each_with_index do |x, row_index|
    (y_pos..(y_pos + columns)).each_with_index do |y, column_index|
      url = "#{url_prefix}#{y}/#{x}#{url_extension}"

      request = Typhoeus::Request.new(url, method: :get)
      request.on_complete do |response|
        blob_grid[column_index][row_index] = response.body
      end

      hydra.queue(request)
    end
  end

  hydra.run

  binding.pry
end
