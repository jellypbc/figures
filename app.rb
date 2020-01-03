require 'sinatra/base'
require 'sinatra/reloader'
require 'open-uri'
require 'json'
# require 'google-cloud-storage'

class App < Sinatra::Base
	# GCS config
	# GCLOUD_BUCKET = "bigiztestbukkit"
	# GCLOUD_PROJECT = "jellyposter"
	# GCLOUD_KEYFILE = "./key.json"

	set :root, File.dirname(__FILE__)
	set :public_folder, File.dirname(__FILE__) + '/public'
	set :logging, true

  configure :development do
    register Sinatra::Reloader
  end

	get '/isAlive' do
	  'Hello world!'
	end

	post '/process' do
	  content_type :json
	  logger.info(params)

	  @pdf_url = params['pdf']
	  halt 422, "Missing PDF url" unless @pdf_url

	  @upload_id = params['upload_id']
	  halt 422, "Missing upload" unless @upload_id

		@file_path = "public/#{@upload_id}"
		@output_pdf = "pdf.pdf"
		@output_json = "pdf.json"

		save_pdf
		run_jar
		rename
		resp = parse_response

		JSON.pretty_generate(resp)
	end

	post '/cleanup/:upload_id' do
		logger.info(params)
		file_path = "public/#{params['upload_id']}"
		resp = cleanup(file_path)

		JSON.pretty_generate(resp)
	end

	def save_pdf
		begin
			Dir.mkdir(@file_path)
			open(@pdf_url) do |hnd|
			  File.open("#{@file_path}/#{@output_pdf}","wb") {|file| file.puts hnd.read }
			end
		rescue OpenURI::HTTPError => e
			halt 422, "Bad PDF URL"
		rescue Errno::EEXIST => e
		  $stderr.puts "Caught the exception: #{e}"
		  halt 422, "Upload folder already exists"
		rescue Errno::ENOENT => e
		  $stderr.puts "Caught the exception: #{e}"
		  halt 422, "No PDF found"
		end
	end

	def run_jar
		# Runs the jar on the PDF
		# system() will log output to console, wait until process finishes
		#
		# e.g. `java
		# 	-jar bin/pdffigures.jar
	  # <input>
	  #       input PDF(s) or directory containing PDFs
	  # -i <value> | --dpi <value>
	  #       DPI to save the figures in (default 150)
	  # -s <value> | --save-stats <value>
	  #       Save the errors and timing information to the given file in JSON fromat
	  # -t <value> | --threads <value>
	  #       Number of threads to use, 0 means using Scala's default
	  # -e | --ignore-error
	  #       Don't stop on errors, errors will be logged and also saved in `save-stats`
	  #  			if set
	  # -q | --quiet
	  #       Switches logging to INFO level
	  # -d <value> | --figure-data-prefix <value>
	  #       Save JSON figure data to '<data-prefix><input_filename>.json'
	  # -c | --save-regionless-captions
	  #       Include captions for which no figure regions were found in the JSON data
	  # -g <value> | --full-text-prefix <value>
	  #       Save the document and figures into '<full-text-prefix><input_filename>.json
	  # -m <value> | --figure-prefix <value>
	  #       Save figures as <figure-prefix><input_filename>-<Table|Figure><Name>-<id>.png.
	  # 			`id` will be 1 unless multiple figures are found with the same `Name` in
	  # 			`input_filename`
	  # -f <value> | --figure-format <value>
	  #       Format to save figures (default png)
		puts ">>>> Running the pdffigures jar"
		system("java -jar bin/pdffigures.jar -g #{@file_path}/ -m #{@file_path}/ #{@file_path}/#{@output_pdf}")
	end

	def upload
		puts ">>>> Upload figures to GCS"
		# require "google/cloud/storage"
		# upload the images to GCS (make idempotent by backgrounding)
		# gcloud = Gcloud.new GCLOUD_PROJECT, GCLOUD_KEYFILE
	 #  storage = gcloud.storage
	 #  bucket = storage.bucket GCLOUD_BUCKET
	 #  bucket.create_file params['myfile'][:tempfile], params['myfile'][:filename]
	end

	def rename
		Dir.glob("#{@file_path}/*{.png}").each_with_index do |f, i|
			File.rename(f, f.gsub("pdf-", ""))
		end
	end

	# Returns the generated results json as a hash, only the figures part
	def parse_response
		file = File.read("#{@file_path}/#{@output_json}")
		data = JSON.parse(file)
		figures_array = data["figures"]
		figures_array.each do |fig|
			fig["renderURL"] = fig["renderURL"]
				.gsub("public/","")
				.gsub("pdf-","")
		end
		figures_array
	end

	# Deletes the generated files
	def cleanup(file_path)
		file_count = 0
		if File.directory?(file_path)
			Dir.foreach(file_path) do |f|
				file_count += 1
			  fn = File.join(file_path, f)
			  File.delete(fn) if f != '.' && f != '..'
			end
			Dir.delete(file_path)
			msg = "Cleaned up #{file_count} files"
		else
			halt 422, "No directory"
		end
		{ msg: msg }
	end

  run! if app_file == $0
end


