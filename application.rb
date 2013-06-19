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

  hydra = Typhoeus::Hydra.new

  # Create an empty grid
  blob_grid = Array.new(columns).map { Array.new(rows) }

  errors = []

  # Setup get requests for each slot in the grid
  (x_pos...(x_pos + rows)).each_with_index do |x, row_index|
    (y_pos...(y_pos + columns)).each_with_index do |y, column_index|
      url = "#{url_prefix}#{y}/#{x}#{url_extension}"

      request = Typhoeus::Request.new(url, method: :get)
      request.on_complete do |response|
        puts "Request #{row_index}-#{column_index} completed!"

        if response.body[/Error/]
          # If errors (which this seems to occasionally), retry

          errors << url
          request = Typhoeus::Request.new(url, method: :get)
          request.on_complete do |response|
            blob_grid[row_index][column_index] = response.body
          end
          hydra.queue(request)

        else
          blob_grid[row_index][column_index] = response.body
        end
      end

      hydra.queue(request)
    end
  end

  # Run all the requests
  hydra.run

  # Create image objects out of blobs
  list = ImageList.new
  blob_grid.each do |column|
    column_list = ImageList.new

    begin
      column_list.from_blob(*column)
    rescue Magick::ImageMagickError => e
      puts "ERRORING URLS:"
      puts errors
      raise e
    end

    list.push(column_list.append(false))
  end

  # Create the image
  image_name = "img#{url_extension}"
  list.append(true).write(image_name)

  send_file image_name
end
