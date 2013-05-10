#Ruby file: pos2bmp.rb
=begin
	This script takes as input a text file of setpos console commands from Counter-Strike: Global Offensive.
	It optionally takes map bounds (xmin, ymin, zmin) (xmax, ymax, zmax)

	It outputs a bitmap 'heatmap' of the file
=end

class Point3
attr_accessor :x, :y, :z
	def initialize(x, y, z)
		@x = x
		@y = y
		@z = z
	end

	def to_s
		"(#{x},\t#{y},\t#{z})"
	end
end

class Bitmap
	def initialize( scores, maxscore, width, height )
		@scores = scores
		@maxscore = maxscore
		@width = width
		@height = height

		@pixel_size = ((24.0*@width)/32.0).ceil * 4 * @height
	end

	def export( filename )
		#Writes the file
		File.open(filename, "wb") do |f|
			write_bmp_header(f)
			write_dib_header(f)
			write_pixels(f)	
		end 
	end

	private
	def write_bmp_header( file )
		#file.write("BMP Header will go here...\n")
		header = [ "BM", 54 + @pixel_size, 0, 0, 54 ]
		file.write( header.pack( "A2Vv2V" ) )
	end

	def write_dib_header( file )
		#file.write("DIB Header will go here...\n")
		header = [40, @width, @height, 1, 24, 0, @pixel_size, 2835, 2835, 0, 0]
		file.write( header.pack( "V3v2V6" ) )
	end 

	def write_pixels( file )
		#file.write("Pixel array will go here...\n")

		#Quartiles
		q1 = (@maxscore/4) * 0.25
		q2 = (@maxscore/4) * 0.50
		q3 = (@maxscore/4) * 0.75
		q4 = (@maxscore/4) * 1.00
		
		pixels = Array.new(@pixel_size)
		index = 0
		rheight = 0
		@scores.reverse_each do |i|
			i.each do |j|
				#pixels
				
				#Calculate the 'heat' value of each pixel
				#Heat value works as follows:
					#The lowest score possible starts with an RGB of 00/00/FF
					#As the score increases, the G value rises until 00/FF/FF
					#As the score increases, the B value lowers until 00/FF/00
					#As the score increases, the R value rises until FF/FF/00
					#As the score increases, the G value lowers until FF/00/00 
					#The highest score possible ends with an RGB of FF/00/00
				
				#As a function of score, from 0 to maxscore...
				case j
					when 0
						red = 0
						blue = 0
						green = 0
					when 1...q1
						red = 0
						green = 255 - ( ( (q1 - j) / q1) * 255).to_i
						blue = 255
					when q1...q2
						red = 0
						green = 255
						blue = ( ( ( (q2 - q1) - (j - q1) ) / (q2 - q1) ) * 255).to_i
					when q2...q3
						red = 255 - ( ( ( (q3 - q2) - (j - q2) ) / (q3 - q2) ) * 255).to_i
						green = 255
						blue = 0
					when q3...q4
						red = 255
						green = ( ( ( (q4 - q3) - (j - q3) ) / (q4 - q3) ) * 255).to_i
						blue = 0
					else
						red = 255 
						green = 0
						blue = 0
				end
				
				#pixels are stored bgr
				pixels[index] = blue 
				pixels[index + 1] = green
				pixels[index + 2] = red
				index += 3
			end
			#padding- dont care what values go in here
			(@width % 4).times do
				pixels[index] = 0
				index += 1
			end

		end
		file.write( pixels.pack("C*") )
	end
end

$POINT_WIDTH = 25

#Case with no arguments
if ARGV.size != 2
	puts "\n\tUsage: pos2bmp.rb <input filename> <output filename>\n"
else


	#Extract data into our points array
	points = Array.new
	i = 0

	#load the input file
	File.open( ARGV[0] ) do |input_lines|
		input_lines.each do |line|
			if line =~ /setpos/
				points[i] = Point3.new(0,0,0)

				#Remove all up to the xcoord (preserve -)
				modline = line.sub(/[^0-9-]*/, "")
				points[i].x = modline[/\S*\s/].to_i

				modline.sub!(/\S*\s/, "")
				points[i].y = modline[/\S*\s/].to_i

				modline.sub!(/\S*\s/, "")
				points[i].z = modline[/\S*\s/].to_i
				i += 1
			end
		end
	end

	#Get minimum/maximum xyz
	min = Point3.new(0,0,0)
	min.x = points[0].x
	min.y = points[0].y
	min.z = points[0].z

	max = Point3.new(0,0,0)
	max.x = points[0].x
	max.y = points[0].y
	max.z = points[0].z

	points.each do |point|
		if point.x < min.x
			min.x = point.x
		end

		if point.x > max.x
			max.x = point.x
		end

		if point.y < min.y
			min.y = point.y
		end

		if point.y > max.y
			max.y = point.y
		end
		
		if point.z < min.z
			min.z = point.z
		end

		if point.z > max.z
			max.z = point.z
		end
	end

	puts "Minimum: #{min}, Maximum: #{max}"
	puts "Number of points: #{points.count}"
	#Modify min and max to have a bit of extra padding, since each point affects a range of scores

	min.x -= $POINT_WIDTH
	min.y -= $POINT_WIDTH
	min.z -= $POINT_WIDTH

	max.x += $POINT_WIDTH
	max.y += $POINT_WIDTH
	max.z += $POINT_WIDTH

	#Create a 2D map based on min/max coords
	scores = Array.new(max.y - min.y + 1) { Array.new(max.x - min.x + 1, 0) }	
	maxscore = 0

	#Scoring the map		
	#	The exact coordinates of the point gets 5 added to its score
	#	Each 'nearby' point gets 1 fewer point for its max distance away on either axis



	points.each do |p|
		( -($POINT_WIDTH-1)..($POINT_WIDTH-1) ).each do |x|
			( -($POINT_WIDTH-1)..($POINT_WIDTH-1) ).each do |y|	
				score = x.abs > y.abs ? $POINT_WIDTH - x.abs : $POINT_WIDTH - y.abs
				scores[p.y - min.y + y][p.x - min.x + x] += score
				if scores[p.y - min.y + y][p.x - min.x + x] > maxscore
					maxscore = scores[p.y - min.y + y][p.x - min.x + x]
				end
			end
		end
	end


	puts "Max score: #{maxscore}"
	#Next step: converting the scores into a true bitmap

	bmpout = Bitmap.new(scores, maxscore, scores[0].size, scores.size)
	bmpout.export( ARGV[1] )
end
