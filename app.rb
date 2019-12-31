require 'sinatra/base'
require 'sinatra/reloader'
require 'open-uri'
require 'json'

DIR_PATH = "tmp/"

class App < Sinatra::Base
	set :root, File.dirname(__FILE__)
	set :logging, true

  configure :development do
    register Sinatra::Reloader
  end

	get '/' do
	  'Hello world!'
	end

	post '/process' do
	  content_type :json
	  resp = process(json_params)
	  resp.to_json
	end

  def json_params
    begin
      JSON.parse(request.body.read)
    rescue
      halt 400, { message:'Invalid JSON' }.to_json
    end
  end

	# accepts :params => :pdf_url, :upload_id
	# todos: error handling
		# DONE no pdf url param
		# DONE no pdf found
		# no java jar failed
		# pdf malformed
		# gcs timeout
	def process(params)
	  @pdf_url = params['pdf']
	  halt 422, "Missing PDF url" unless @pdf_url
	  @upload_id = params['upload_id']
	  halt 422, "Missing upload" unless @upload_id

		@file_path = "tmp/#{@upload_id}"
		@output_pdf = "pdf.pdf"
		@output_json = "pdf.json"

		yunits = "https://storage.googleapis.com/jellyposter-store/d5058c6990e36d68068ad98422372b6b.pdf"
		parsrc = "https://storage.googleapis.com/jellyposter-store/8956e224c520067e5c2082d681416d7d.pdf"

		# save_pdf
		run_jar
		rename
		upload
		resp = parse_response
		# cleanup
		resp
	end

	def save_pdf
		begin
			Dir.mkdir(@file_path)
			open(@pdf_url) do |hnd|
			  File.open("#{@file_path}/#{@output_pdf}","wb") {|file| file.puts hnd.read }
			end
		rescue Errno::EEXIST => e
		  $stderr.puts "Caught the exception: #{e}"
		  halt 422, "Upload folder already exists"
		rescue Errno::ENOENT => e
		  $stderr.puts "Caught the exception: #{e}"
		  halt 422, "No PDF found"
		end
	end

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
	def run_jar
		puts ">>>> Running the jar"
		system("java -jar bin/pdffigures.jar -g #{@file_path}/ -m #{@file_path}/ #{@file_path}/#{@output_pdf}")
	end

	# upload the images to GCS (make idempotent by backgrounding)
	def upload
		puts ">>>> Upload figures to GCS"

		Dir.glob("#{@file_path}/*{.png}").each_with_index do |f, i|
			File.rename(f, DIR_PATH + "/" + "figure-#{i+1}" + File.extname(f))
		end
	end

	def rename
		Dir.glob("#{@file_path}/*{.png}").each_with_index do |f, i|
			File.rename(f, f.gsub("pdf-", ""))
		end
	end

	# returns the generated results json as a hash, only the figures part
	def parse_response
		# todo: merge in updated GCS url
		file = File.read("#{@file_path}/#{@output_json}")
		data_hash = JSON.parse(file)
		data_hash["figures"]
	end

	# deletes the generated files
	def cleanup
		file_count = 0
		Dir.foreach(DIR_PATH) do |f|
			file_count += 1
		  fn = File.join(DIR_PATH, f)
		  File.delete(fn) if f != '.' && f != '..'
		end
		puts ">>>> Cleaned up #{file_count} files"
	end

  run! if app_file == $0
end


