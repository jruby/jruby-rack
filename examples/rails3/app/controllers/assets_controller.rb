class AssetsController < ApplicationController
  def show
    image_name, image_type = params[:id], params[:format]
    filename = Rails.public_path + "/images/#{image_name}.#{image_type}"
    if File.file?(filename)
      image_data = File.read filename
      response.headers['Content-Description'] = "This is #{image_name}.#{image_type}"
      response.headers['Last-Modified'] = File.mtime(filename).rfc822
      send_data image_data, :type => "image/#{image_type}", :disposition => 'inline'
    else
      render :text => "<h1>Not Found</h1>", :status => :not_found
    end
  end
end
