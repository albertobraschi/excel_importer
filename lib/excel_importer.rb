class ExcelImporter; end
require File.dirname(__FILE__) + '/excel_importer/column_definer'
require File.dirname(__FILE__) + '/excel_importer/result_set'

silence_warnings {
  require 'parseexcel'
}

class ExcelImporter
  def initialize(model)
    @columns = []
    @model = model
    yield ColumnDefiner.new(self)
  end
  
  def import(filename)
    sheet = Spreadsheet::ParseExcel.parse(filename).worksheet(0)

    returning ResultSet.new do |result|
      sheet.each(1) do |row|
        instance = create_from_row(row)
        
        if instance.save
          result.saved << instance
        else
          result.unsaved << instance
        end
        
        result.all << instance
      end
    end
  end
  
  def add_column(field, type)
    @columns << [ field, type ]
  end
  
  def ignore_column
    @columns << nil
  end
  
private
  def create_from_row(row)
    returning @model.new do |r|
      @columns.each_with_index do |column, i|
        if column
          field, type = column

          cell = row.at(i)
          r.send("#{field}=", read_cell(cell, type)) if field && type && !cell.blank?
        end
      end
    end
  end
  
  def read_cell(cell, type)
    case type
    when :string, :text
      cell.to_s('utf8').gsub(/[^ \(\)a-zA-Z0-9,\.'"&\/:-]/, '').strip
    when :integer
      cell.to_i
    when :date
      cell.to_i > 0 ? cell.date : nil
    when Proc
      type.call(cell)
    end
  end
end
