require 'logger'
require 'goodreads'
require 'airrecord'
require_relative 'goodreads_client'
require_relative 'book'

class Importer
  USER_ID = 2419634
  READ    = 'read'
  TO_READ = 'to-read'

  def self.import_from_goodreads
    existing_books = Book.all

    # logger.info("Starting shelf: #{TO_READ}")
    # self.import_from_shelf(TO_READ, existing_books)

    # logger.info("Starting shelf: #{READ}")
    # self.import_from_shelf(READ, existing_books)

    # shelf = 'npr-top-100-science-fiction-fantasy'
    # logger.info("Starting shelf: #{shelf}")
    # self.import_from_shelf(shelf, existing_books)

    shelf = 'currently-reading'
    logger.info("Starting shelf: #{shelf}")
    self.import_from_shelf(shelf, existing_books)

    # shelf = 'on-deck'
    # logger.info("Starting shelf: #{shelf}")
    # self.import_from_shelf(shelf, existing_books)
  end

  private

    def self.import_from_shelf(shelf_name, existing_books)
      page = 1

      loop do
        shelf = GoodreadsClient::Client.shelf(USER_ID, shelf_name, { sort: 'date_read', order: 'd', per_page: 200, page: page })
        # shelf = GoodreadsClient::Client.shelf(USER_ID, shelf_name, { sort: 'date_read', order: 'd', per_page: 1, page: 12 })
        found_books = shelf['total']
        currently_processed_books = page * 200
        books        = shelf.books
        books_length = books.length

        logger.info("")
        logger.info("Found #{found_books} books. Looking at page #{page}, total processed: #{currently_processed_books}")

        books.each_with_index do |shelf_book, idx|
          book            = shelf_book.book
          existing_book   = find_existing_book(existing_books, book)
          logger.info("#{idx+1}/#{books_length} - #{book.title}")
          if existing_book
            existing_book.create_from_goodreads(book, shelf_book)
          else
            Book.new("Title" => book.title).create_from_goodreads(book, shelf_book)
          end
        end

        break if currently_processed_books >= found_books
        page = page + 1
      end
    end

    def self.find_existing_book(existing_books, book)
      existing_books.find { |other| other["Title"] == book.title_without_series }
    end

    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    # def self.get_shelf(shelf_name)
    #   GoodreadsClient::Client.shelf(USER_ID, shelf_name)
    # end
end

Airrecord.api_key = ENV['AIRTABLE_KEY']
Importer.import_from_goodreads
