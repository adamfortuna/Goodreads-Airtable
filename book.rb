require 'byebug'
require_relative 'author'
require_relative 'serie'
require_relative 'shelf'
require_relative 'category'
require_relative 'goodreads_client'

class Book < Airrecord::Table
  self.base_key = 'app9kWZ1eEhSFtmDs'
  self.table_name = 'Books'

  GOODREADS_BLACKLIST = %w(
    to-read favorites currently-reading owned
    series favourites re-read owned-books
    books-i-own wish-list si audiobook
    book-club ebook kindle to-buy
  )

  GOODREADS_MERGE = {
    "Non-fiction" => "Nonfiction",
    "Classic" => "Classics",
    "Cookbook" => "Cooking",
    "Cookbooks" => "Cooking",
    "Biography" => "Memoir",
    "Biographies" => "Memoir",
    "Autobiography" => "Memoir",
    "Auto-biography" => "Memoir",
    "Sci-fi" => "Science Fiction",
    "Scifi" => "Science Fiction",
    "Management" => "Leadership",
    "Self-help" => "Personal Development",
    "Selfhelp" => "Personal Development",
    "Personal-development" => "Personal Development",
    "Self-improvement" => "Personal Development",
    "Science-fiction" => "Science Fiction",
    "Ya" => "Young-adult",
    "Tech" => "Technology",
    "Young-adult" => "Young Adult",
    "Computer-science" => "Programming",
    "Investing" => "Economics",
    "Fitness" => "Health",
    "Food" => "Cooking",
    "Finance" => "Economics",
    "Software" => "Programming",
    "Literature" => "Classics",
  }

  CATEGORIES = [
    "Business", "Psychology", "Science", "Personal Development", "Philosophy",
    "History", "Fiction", "Memoir", "Leadership", "Classics", "Economics",
    "Cooking", "Programming", "Health", "Politics", "Technology", "Science Fiction",
    "Entrepreneurship", "Design", "Writing", "Fantasy", "Young Adult", "Nonfiction",
  ]

  # Create a Book record from a Goodreads API request
  def create_from_goodreads(book, shelf_book)
    personal_rating = shelf_book.rating.to_i

    self['ISBN']              = book.isbn13
    self['Title']             = book.title_without_series
    self['Cover']             = create_cover(book)
    self['Categories']        = create_categories(goodreads_categories)
    series, series_number     = create_series(book.title)
    self['Series']            = series
    self['Series Number']     = series_number
    self['Publication Year']  = book.publication_year.to_s if !book.publication_year.blank?
    self['Goodreads Rating']  = book.average_rating.to_f
    self['Personal Rating']   = personal_rating if personal_rating > 0
    self['Goodreads URL']     = book.link
    self['Pages']             = book.num_pages.to_i
    authors                   = [book.authors.author].flatten
    self['Authors']           = create_author(authors)
    self['Shelves']           = create_shelves(shelf_book.shelves)

    self['Goodreads Ratings'] = book.ratings_count.to_i
    self['Date Started']      = shelf_book.started_at ? shelf_book.started_at.to_datetime : nil
    self['Date Read']         = shelf_book.read_at ? shelf_book.read_at.to_datetime : nil
    self['Read']              = !self['Date Read'].nil?
    self.save
  end

  private

    def create_cover(book)
      [
        {
          "url": book.image_url
        }
      ]
    end

    def create_categories(categories)
      category_ids     = []
      existing_categories = Category.all
      categories.each do |category|
        existing_category = existing_categories.find {|a| a['Name'] == category}
        category_ids <<
              if existing_category
                existing_category.id
              else
                Category.create("Name" => category).id
              end
      end
      category_ids
    end

    def goodreads_categories(n = 5)
      popular = goodreads_book.popular_shelves
      return [] if popular.blank?

      shelves = popular.shelf
      return [] unless shelves.first.respond_to?(:name)

      shelves.map(&:name).reject { |name|
        GOODREADS_BLACKLIST.include?(name)
      }.first(n).map { |name|
        name = name.capitalize
        name = GOODREADS_MERGE[name] if GOODREADS_MERGE[name]
        (CATEGORIES.include?(name) && name) || nil
      }.compact.uniq
    end

    def goodreads_id
      query = self["ISBN"] if self["ISBN"]
      query ||= "\"#{self['Title']}\""

      search = goodreads_client.search_books(query)
      if search.results.respond_to?(:work)
        matches = [search.results.work].flatten

        best_match ||= matches.first
        return unless best_match
        best_match.best_book.id
      end
    end

    def goodreads_book
      goodreads_client.book(goodreads_id)
    end

    def goodreads_client
      GoodreadsClient::Client
    end

    # Create or find Series
    def create_series(title)
      return [], nil if !title[/\((.*?)\)/]
      series_title_with_number = title[/\((.*?)\)/][1..-2]
      if series_title_with_number.include?('#')
        series_title  = series_title_with_number.split('#')[0].tr('^a-zA-Z ', '').strip
        series_number = series_title_with_number.split('#')[1].tr('^0-9.-', '')
      elsif match = series_title_with_number.match(/(0-9)+\.(0-9)$/)
        series_number =  match[0]
        series_title = series_title_with_number.gsub(series_number, '').strip
      end

      existing_serie = Serie.all.find {|a| a['Title'] == series_title}
      if existing_serie
        return [existing_serie.id], series_number
      else
        return [Serie.create('Title' => series_title).id], series_number
      end
    rescue Exception => e
      byebug
      raise e
    end

    # Create or find author
    def create_author(authors)
      author_ids       = []
      existing_authors = Author.all
      authors.each do |author|
        existing_author = existing_authors.find {|a| a['Name'] == author.name}
        author_ids <<
              if existing_author
                existing_author.id
              else
                Author.create("Name" => author.name).id
              end
      end
      author_ids
    end

    # Create of find shelves
    def create_shelves shelves
      shelf_ids = []
      existing_shelves = Shelf.all

      if shelves.shelf.class.to_s == 'Array'
        shelves.shelf.each do |shelf|
          existing_shelf = existing_shelves.find {|a| a['Name'] == shelf.name}
          shelf_ids << (existing_shelf ? existing_shelf.id : Shelf.create("Name" => shelf.name).id)
        end
      else
        existing_shelf = existing_shelves.find {|a| a['Name'] == shelves.shelf.name}
        shelf_ids << (existing_shelf ? existing_shelf.id : Shelf.create("Name" => shelves.shelf.name).id)
      end

      shelf_ids
    end
end
