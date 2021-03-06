require 'flickraw'
module Lulz
	class GrabFlickrAgent < Agent

		default_process :process
		 set_description "grab flickr stuff"
			analyzer
		 def self.accepts?(pred)
         subject=pred.subject
         return (pred.subject.is_a? FlickrProfile and !is_processed?(subject))
      end

		

		def process(pred)
			subject=pred.subject
			set_processed subject
			user_id=subject.user_id

			results=500
			photos=[]
			page=1
			groups=flickr.people.getPublicGroups(:user_id => user_id)
			groups.each do |group|
				g=group.name
				g << " (admin)" if group.admin!=0
				g << " (18+)" if group.eighteenplus!=0
				brute_fact_nomatch subject, :flickr_group, g, :collect_as => :flickr_groups
			end
			while(results==500)
				r=flickr.people.getPublicPhotos(:user_id => user_id, :extras => "license, date_upload, date_taken, owner_name, icon_server, original_format, last_update, geo, tags, machine_tags, o_dims, views, media, path_alias, url_sq, url_t, url_s, url_m, url_o",:per_page => 500, :page => page)
				activity
				results=r.count
				photos=photos+r
				page=page+1
			end
			noexif=false
			photos.each do |photo|
				pp photo
				fp=FlickrPhoto.new(photo.id)
				fp.longitude=photo.longitude
				fp.latitude=photo.latitude
				fp.tags=photo.tags
				fp.date_taken=photo.datetaken
				fp.date_uploaded=photo.dateupload
				fp.url=photo.url_o if photo.respond_to? :url_o
				fp.url=photo.url_m if fp.url.blank? and photo.respond_to? :url_m
				brute_fact_nomatch fp, :title, photo.title
				if archive?
					info=flickr.photos.getInfo(:photo_id=>fp.photo_id)
					activity
					brute_fact_nomatch fp, :description, info.description
					info.notes.each do |note|
					brute_fact_nomatch fp, :note, note.to_s
					end

					# TODO: add in exif support
				end
				noexif=true
				begin
					unless noexif
						exif=flickr.photos.getExif(:photo_id=>fp.photo_id)
						pp exif
						activity
					end	
				rescue Exception => e
					noexif=true
				end
				brute_fact subject,:photo,fp,:collect_as => :photos
			end
				
		end

		private

		def parse_blog_posts(profile,page)
			rows=page.root.css("#BlogTable tr")
			rows.each do |row|
				timestamp=row.css(".blogTimeStamp").text.strip rescue nil
				next if timestamp.blank?
				subject=row.css(".blogSubject").text.strip rescue nil
				content=row.css(".blogContent").inner_html.strip
				time_cell=row.css(".blogContentInfo .cmtcell").first
				time=time_cell.text
				timestamp="#{timestamp} #{time}"
				canon=time_cell.css("a").first.attributes["href"].to_s
				post=Post.new
				post.subject=subject
				post.posted_at=DateTime.parse(timestamp) rescue nil
				post.canonical_url=URI.parse(canon) rescue nil
				post.contents=content
				brute_fact_nomatch profile,:post,post
			end
		end


	end
end
