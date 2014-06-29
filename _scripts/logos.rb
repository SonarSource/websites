require 'erb'
require 'optparse'
require 'csv'

# Read options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: logos.rb [options]"
  opts.on('-u', '--url URL', 'Target URL to directory of images, for example images/ or http://sonarsource.com/images/. Must end with slash.') do |v|
  	options[:url] = v
  end
  opts.on('-o', '--output FILE', 'Path to generated HTML file') do |v|
  	options[:output] = v
  end
end.parse!
images_url = options[:url] || 'images/'
path = options[:output] || '../logos.html'


class Account
  attr_reader :id, :name, :image

  def initialize(id, name, image)
    @id = id
    @name = name
    @image = (image && image.size>0 && image != 'none') ? image : nil
  end

  def image?
    @image != nil
  end

  def to_s
    "#{@name}: #{image}"
  end
end

# Load accounts. Remove the first line (titles)
accounts = []
missings = []
CSV.foreach("logos.csv", :force_quotes => true, :col_sep => ',', :quote_char => '"') do |row|
  account_id = row[0].gsub('"', '').strip
  account_name = row[1].gsub('"', '').strip
  image = row[2].gsub('"', '').strip
  account = Account.new(account_id, account_name, image)
  accounts << account
  if account.image?
    missings << account unless File.exist?("../images/#{account.image}")
  end
end

unless missings.empty?
  missings.each { |missing| puts "Missing: #{missing}" }
  raise "Missing images"
end

accounts_by_image = accounts.select{|a| a.image?}.group_by(&:image)||[]

# Log synthesis
puts "#{accounts.size} accounts"
puts "#{accounts.reject{|a| a.image?}.size} accounts without logo"
puts "#{accounts_by_image.size} of logos"


# Log accounts with same image
accounts_by_image.each_pair do |image, accounts|
  if accounts.size>1
    puts "Same logo for #{accounts.map(&:name)}"
  end
end

# Build HTML template
ROW_SIZE=3
template = <<-TEMPLATE
<!-- Generated on <%= Time.now -%> -->
<table class="customers" style="width: 679px;" border="0" cellspacing="0" cellpadding="0">
  <tbody>
    <% accounts_by_image.keys.each_slice(ROW_SIZE).to_a.each do |row| %>
    <tr style="height: 90px;">
      <% row.each do |image| %>
        <td align="center" valign="middle"><img src="<%= images_url -%><%= image -%>" /></td>
      <% end %>
      <% for i in row.size...ROW_SIZE do %>
        <td align="center" valign="middle"></td>
      <% end %>
    </tr>
    <% end %>
  </tbody>
</table>
TEMPLATE


# Generate HTML
File.open(path, 'w') do |output|
  output.puts ERB.new(template, nil, '-').result(binding)
end

puts "#{path} generated"
