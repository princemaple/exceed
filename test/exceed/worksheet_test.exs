defmodule Exceed.WorksheetTest do
  # @related [subject](lib/exceed/worksheet.ex)
  use Test.SimpleCase, async: true
  alias Exceed.Worksheet
  alias XmlQuery, as: Xq

  setup do
    stream =
      Stream.unfold(1, fn
        100 -> nil
        row -> {["row #{row} cell 1", row, row * 1.5], row + 1}
      end)

    headers = ["inline strings", "integers", "floats"]

    [headers: headers, stream: stream]
  end

  describe "new" do
    test "captures inputs", %{headers: headers, stream: stream} do
      assert %Worksheet{name: "sheet", headers: ^headers, content: ^stream, opts: []} =
               Worksheet.new("sheet", headers, stream)
    end
  end

  describe "to_xml" do
    test "generates rows for the headers and each member of the stream", %{headers: headers, stream: stream} do
      ws = Worksheet.new("sheet", headers, Enum.take(stream, 2))
      xml = Worksheet.to_xml(ws) |> stream_to_xml()

      assert [header_row, row_1, row_2] = Xq.all(xml, "/worksheet/sheetData/row")

      assert header_row |> Xq.attr("r") == "1"

      header_row
      |> extract_cells()
      |> assert_eq([
        %{type: "inlineStr", text: "inline strings", children: "is/t", cell: "A1"},
        %{type: "inlineStr", text: "integers", children: "is/t", cell: "B1"},
        %{type: "inlineStr", text: "floats", children: "is/t", cell: "C1"}
      ])

      row_1
      |> extract_cells()
      |> assert_eq([
        %{type: "inlineStr", text: "row 1 cell 1", children: "is/t", cell: "A2"},
        %{type: "n", text: "1", children: "v", cell: "B2"},
        %{type: "n", text: "1.5", children: "v", cell: "C2"}
      ])

      row_2
      |> extract_cells()
      |> assert_eq([
        %{type: "inlineStr", text: "row 2 cell 1", children: "is/t", cell: "A3"},
        %{type: "n", text: "2", children: "v", cell: "B3"},
        %{type: "n", text: "3.0", children: "v", cell: "C3"}
      ])
    end

    test "configures each column as wide as the header plus some default padding",
         %{headers: headers, stream: stream} do
      ws = Worksheet.new("sheet", headers, Enum.take(stream, 0))
      xml = Worksheet.to_xml(ws) |> stream_to_xml()

      [header1, header2, header3] = headers

      assert [col1, col2, col3] = Xq.all(xml, "/worksheet/cols/col")

      assert String.length(header1) == 14
      assert Xq.attr(col1, "min") == "1"
      assert Xq.attr(col1, "max") == "1"
      assert Xq.attr(col1, "width") == "18.25"

      assert String.length(header2) == 8
      assert Xq.attr(col2, "min") == "2"
      assert Xq.attr(col2, "max") == "2"
      assert Xq.attr(col2, "width") == "12.25"

      assert String.length(header3) == 6
      assert Xq.attr(col3, "min") == "3"
      assert Xq.attr(col3, "max") == "3"
      assert Xq.attr(col3, "width") == "10.25"
    end

    test "can set the column width padding",
         %{headers: headers, stream: stream} do
      ws = Worksheet.new("sheet", headers, Enum.take(stream, 0), col_padding: 2.34)
      xml = Worksheet.to_xml(ws) |> stream_to_xml()

      [header1, header2, header3] = headers

      assert [col1, col2, col3] = Xq.all(xml, "/worksheet/cols/col")

      assert String.length(header1) == 14
      assert Xq.attr(col1, "width") == "16.34"

      assert String.length(header2) == 8
      assert Xq.attr(col2, "width") == "10.34"

      assert String.length(header3) == 6
      assert Xq.attr(col3, "width") == "8.34"
    end
  end

  # # #

  defp extract_cells(row) do
    row
    |> Xq.all("//c")
    |> Enum.map(fn cell ->
      case Xq.attr(cell, "t") do
        "inlineStr" ->
          %{
            cell: Xq.attr(cell, "r"),
            children: "is/t",
            text: Xq.find!(cell, "//is/t") |> Xq.text(),
            type: "inlineStr"
          }

        "n" ->
          %{
            cell: Xq.attr(cell, "r"),
            children: "v",
            text: Xq.find!(cell, "//v") |> Xq.text(),
            type: "n"
          }
      end
    end)
  end
end