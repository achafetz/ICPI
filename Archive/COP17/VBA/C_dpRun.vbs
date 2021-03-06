Option Explicit
'ABOUT: This series of subs creates the Data Pack and its supplemental _
files for use in the FY 2017 COP. This sub is run via the RUN button on _
the POPrun tab of the template. The RUN button initiates the generation _
form for choosing the OUs and Data Pack products

'variables
        Public celltxt As String
        Public colIND As Integer
        Public colSNU As Integer
        Public compl_fldr As String
        Public dataWkbk As Workbook
        Public DefPath As String
        Public DEN As String
        Public dpWkbk As Workbook
        Public FileNameZip As String
        Public FirstColumn As Integer
        Public FirstRow As Integer
        Public fname_dp As String
        Public FolderName As String
        Public i As Integer
        Public IND
        Public indColNum As Integer
        Public IndicatorCount As Integer
        Public INDnames
        Public indRng As Range
        Public LastColumn As Integer
        Public LastRow As Integer
        Public LastRowRC As Integer
        Public NUM As String
        Public oApp As Object
        Public OpUnit As Object
        Public OpUnit_ns As String
        Public other_fldr As String
        Public OUcompl_fldr As String
        Public OUpath As String
        Public path As String
        Public pulls_fldr As String
        Public rcDEN As Integer
        Public rcNUM As Integer
        Public rng As Integer
        Public SelectedOpUnits
        Public sht As Variant
        Public shtNames As Variant
        Public snu_unique As Integer
        Public spkGrp As SparklineGroup
        Public strDate As String
        Public tmplWkbk As Workbook
        Public uniqueTot As Integer
        Public view As String



Sub loadform()
    'prompt for form to load to choose OUs to run
    frmRunSel.Show

End Sub


Sub PopulateDataPack()
    'turn off screen updating
        Application.ScreenUpdating = False
        Debug.Print Application.ScreenUpdating
    'establish OUs on ref sheet
        Sheets("POPref").Activate
        rng = Sheets("POPref").Range("D5").Value + 1
        Set SelectedOpUnits = Sheets("POPref").Range(Cells(2, 6), Cells(rng, 6))
    'setup folders
        Call fldrSetup
    'define template workbook
        Set tmplWkbk = ActiveWorkbook
    ' whether to view or just store change forms
        view = Sheets("POPref").Range("D11")

    For Each OpUnit In SelectedOpUnits

        'remove space and comma for file saving (ns = no space)
        OpUnit_ns = Replace(Replace(OpUnit, " ", ""), "'", "")
        'create OU specific folder
        OUpath = compl_fldr & OpUnit_ns & VBA.format(Now, "yyyy.mm.dd")
        If Len(Dir(OUpath, vbDirectory)) = 0 Then MkDir OUpath
        OUcompl_fldr = OUpath & "\"

        'run through all subs
        Call Initialize
        Call getData
        Call formatTable
        Call yieldFormulas
        Call commentCluster
        Call setupSNUs
        Call setupHTCDistro
        Call lookupsumFormulas
        Call sparkTrends
        shtNames = Array("DATIM Indicator Table", "Assumption Input", "HTC Target Calculation", _
            "Target Calculation", "SNU Targets for EA", "Key Ind Trends")
        Call format
        Call formatHeaders
        Call showChanges
        shtNames = Array("Assumption Input", "Target Calculation", "HTC Target Calculation", _
            "SNU Targets for EA", "Key Ind Trends")
        Call filters
        Call dimDefault
        'Call updateOutput
        Call imTargeting
        shtNames = Array("Allocation by IM", "PBAC IM Targets")
        Call format
        Call imshowChanges
        Call filters
        Call saveFile

        'Zip output folder
        If tmplWkbk.Sheets("POPref").Range("D14").Value = "Yes" Then
            Call Zip_All_Files_in_Folder
        End If

    Next

    'close global dataset
     dataWkbk.Close

End Sub


Sub fldrSetup()
    'for saving/opening:
        'set path
            If Sheets("POPref").Range("D17").Value = 0 Then
                'browse to folder
                    MsgBox "Browse to the DataPack folder.", vbInformation, "Find DataPack"
                    With Application.FileDialog(msoFileDialogFolderPicker)
                        .AllowMultiSelect = False
                        .Show
                        On Error Resume Next
                        path = .SelectedItems(1) & "\"
                        Err.Clear
                        On Error GoTo 0
                    End With
                'if no folder select, end sub
                    If Len(path) = 0 Then End
                'ask user if file location is correct; end if not
                    If MsgBox(path & vbCr & "Is this the location?", vbYesNo) = vbNo Then End
                'add path
                    Sheets("POPref").Range("D17").Value = path
            Else
                path = Sheets("POPref").Range("D17").Value
            End If
        ' set folder directory
            pulls_fldr = path & "DataPulls\"
            compl_fldr = path & "CompletedDataPacks\"
            other_fldr = path & "OtherInfo\"
        'set directory initially to the pulls folder
            ChDir (path)
End Sub

Sub Initialize()
    'snu & site level for OU
        tmplWkbk.Sheets("POPref").Activate
    'create datapack file for OU (copy sheets over to new book)
        tmplWkbk.Activate
        Sheets(Array("Home", "Assumption Input", "Target Calculation", "DATIM Indicator Table", "HTC Target Calculation", "Key Ind Trends", "SNU Targets for EA", "Allocation by IM", "PBAC IM Targets", "Change Form")).Copy
        Set dpWkbk = ActiveWorkbook
        ActiveWorkbook.Theme.ThemeColorScheme.Load (other_fldr & "Adjacency.xml")
    'hard code update date into home tab & insert OU name
        Sheets("Home").Range("N1").Select
        Range("N1").Copy
        Selection.PasteSpecial Paste:=xlPasteValues
        Range("O1").Value = OpUnit
        Range("AA1").Select
    'Open data file file
        Workbooks.OpenText Filename:=pulls_fldr & "Global_PSNU_*.xlsx"
        Sheets("DATIM Indicator Table").Activate
        Set dataWkbk = ActiveWorkbook

End Sub

Sub getData()
    'make sure file with data is activate
        dataWkbk.Activate
        Sheets("DATIM Indicator Table").Activate
    ' find the last column
        LastColumn = Range("A1").CurrentRegion.Columns.Count
    'copy variable names
        Range(Cells(1, 2), Cells(1, LastColumn)).Select
    'copy the data and paste in the data pack
        Selection.Copy
        dpWkbk.Activate
        Sheets("DATIM Indicator Table").Activate
        Range("B4").Select
        Selection.PasteSpecial Paste:=xlPasteValues
    'copy formula to look up variable title
        Range("F3").Copy
        Range(Cells(3, 6), Cells(3, LastColumn)).Select
        ActiveSheet.Paste
        Application.CutCopyMode = False
    'hard copy
        Range(Cells(3, 5), Cells(3, LastColumn)).Select
        Selection.Copy
        Selection.PasteSpecial Paste:=xlPasteValues
        Application.CutCopyMode = False
    'find first and last row of OU
        dataWkbk.Activate
        FirstRow = Range("A:A").Find(what:=OpUnit, After:=Range("A1")).Row
        LastRow = Range("A:A").Find(what:=OpUnit, After:=Range("A1"), searchdirection:=xlPrevious).Row
    'how many SNUs?
        uniqueTot = LastRow - FirstRow + 1
        dpWkbk.Names.Add Name:="snu_unique", RefersToR1C1:=uniqueTot
    ' find the last column
        LastColumn = Range("A1").CurrentRegion.Columns.Count
    'select OU data from global file to copy to data pack
        Range(Cells(FirstRow, 2), Cells(LastRow, LastColumn)).Select
    'copy the data and paste in the data pack
        Selection.Copy
        dpWkbk.Activate
        Sheets("DATIM Indicator Table").Activate
        Range("B7").Select
        Selection.PasteSpecial Paste:=xlPasteValues

    'get quarterly data for trends tab
        dataWkbk.Activate
        Sheets("Key Ind Trends").Activate
    'find the last column
        LastColumn = Range("A1").CurrentRegion.Columns.Count
    'find first and last row of OU
        FirstRow = Range("A:A").Find(what:=OpUnit, After:=Range("A1")).Row
        LastRow = Range("A:A").Find(what:=OpUnit, After:=Range("A1"), searchdirection:=xlPrevious).Row
    'select OU data from global file to copy to data pack
        Range(Cells(FirstRow, 4), Cells(LastRow, LastColumn)).Select
    'copy the data and paste in the data pack
        Selection.Copy
        dpWkbk.Activate
        Sheets("Key Ind Trends").Activate
        Range("C7").Select
        Selection.PasteSpecial Paste:=xlPasteValues
        Selection.NumberFormat = "#,##0"
End Sub

Sub formatTable()
    'DATIM Indicator Table
         Sheets("DATIM Indicator Table").Activate
    'find last row and column
        LastColumn = Range("C4").CurrentRegion.Columns.Count
        LastRow = uniqueTot + 6
    'format numbers (eg 10,000)
        Range(Cells(5, 5), Cells(LastRow, LastColumn)).Select
        Selection.NumberFormat = "#,##0"
    'add total to table
        Range("C5").Select
        ActiveCell.Value = "Total"
        Range(Cells(5, 6), Cells(5, LastColumn)).Select
        With Selection
            .Formula = "=SUBTOTAL(109, F6:F" & LastRow & ")"
            .NumberFormat = "#,##0"
        End With
    'format prevention (eg 10.2) and delete total
        'colIND = WorksheetFunction.Match("prevalence_num", dpWkbk.Sheets("DATIM Indicator Table").Range("4:4"), 0)
        'Cells(5, colIND).Value = ""
        'Range(Cells(5, colIND), Cells(LastRow, colIND)).Select
        'Selection.NumberFormat = "#,##0.0"
    'add filter row
        Range(Cells(6, 2), Cells(6, LastColumn)).Select
        Range(Cells(6, 3), Cells(6, LastColumn)).Select
        With Selection.Interior
            .Pattern = xlSolid
            .PatternColorIndex = xlAutomatic
            .ThemeColor = xlThemeColorAccent4
            .TintAndShade = 0.399975585192419
            .PatternTintAndShade = 0
        End With
        Range(Cells(6, 3), Cells(LastRow, LastColumn)).Select
        Selection.AutoFilter
        Range("C6").Select
        With Selection
            .FormulaR1C1 = "Filter Row"
            .NumberFormat = ";;;"
        End With
    'wrap headers in table
        Range(Cells(3, 4), Cells(3, LastRow)).WrapText = True
    'add data validation for prioritization
        Range(Cells(7, 5), Cells(LastRow, 5)).Select
        Selection.Validation.Add Type:=xlValidateList, AlertStyle:=xlValidAlertStop, Operator:= _
            xlBetween, Formula1:="ScaleUp Sat, ScaleUp Agg, Sustained, Ctrl Supported, Sustained Com, Attained, NOT DEFINED, Mil"
        Sheets("Assumption Input").Activate
        Range(Cells(7, 4), Cells(LastRow, 4)).Select
        Selection.Validation.Add Type:=xlValidateList, AlertStyle:=xlValidAlertStop, Operator:= _
            xlBetween, Formula1:="ScaleUp Sat, ScaleUp Agg, Sustained, Ctrl Supported, Sustained Com, Attained, NOT DEFINED, Mil"
        Sheets("DATIM Indicator Table").Activate
    'add named ranges
        Range(Cells(4, 3), Cells(LastRow, LastColumn)).Select
        Application.DisplayAlerts = False
        Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
        Application.DisplayAlerts = True

End Sub

Sub yieldFormulas()
    'add in formulas for yields
        INDnames = Array("pmtct_eid_yield", "pmtct_stat_yield", "tb_stat_yield", "tx_ret_yield", "tx_ret_u15_yield", _
            "htc_tst_u15_yield", "htc_tst_spd_tot_pos")
        For Each IND In INDnames
            If IND = "pmtct_eid_yield" Then
                NUM = "pmtct_eid_pos_12mo"
                DEN = "pmtct_eid"
            ElseIf IND = "pmtct_stat_yield" Then
                NUM = "pmtct_stat_pos"
                DEN = "pmtct_stat"
            ElseIf IND = "tb_stat_yield" Then
                NUM = "tb_stat_pos"
                DEN = "tb_stat"
            ElseIf IND = "tx_ret_yield" Then
                NUM = "tx_ret"
                DEN = "tx_ret_D"
            ElseIf IND = "tx_ret_u15_yield" Then
                NUM = "tx_ret_u15"
                DEN = "tx_ret_u15_D"
            ElseIf IND = "htc_tst_u15_yield" Then
                NUM = "htc_tst_u15_pos"
                DEN = "htc_tst_u15"
            ElseIf IND = "htc_tst_spd_tot_pos" Then
                NUM = "htc_tst_spd_tot_pos"
                DEN = "htc_tst_spd_tot_pos"
            Else
            End If
            colIND = WorksheetFunction.Match(IND, ActiveWorkbook.Sheets("DATIM Indicator Table").Range("4:4"), 0)
            rcNUM = WorksheetFunction.Match(NUM, ActiveWorkbook.Sheets("DATIM Indicator Table").Range("4:4"), 0) - colIND
            rcDEN = WorksheetFunction.Match(DEN, ActiveWorkbook.Sheets("DATIM Indicator Table").Range("4:4"), 0) - colIND
            If IND = "pre_art_yield" Or IND = "pre_art_u15_yield" Then
                Cells(5, colIND).FormulaR1C1 = "=IFERROR(IF(RC[" & rcDEN & "] - RC[" & rcNUM & "]<0,0,(RC[" & rcDEN & "] - RC[" & rcNUM & "])/ RC[" & rcDEN & "]),0)"
            ElseIf IND = "htc_tst_spd_tot_pos" Then
                rcNUM = 1 - Application.WorksheetFunction.CountIf(Range("4:4"), "htc_tst_spd*_pos")
                Cells(5, colIND).FormulaR1C1 = "=SUM(RC[" & rcNUM & "]:RC[-1])"
            Else
                Cells(5, colIND).FormulaR1C1 = "=IFERROR(RC[" & rcNUM & "]/ RC[" & rcDEN & "],"""")"
            End If
            If IND <> "htc_tst_spd_tot_pos" Then Cells(5, colIND).NumberFormat = "0.0%"
            Cells(5, colIND).Copy
            Range(Cells(7, colIND), Cells(LastRow, colIND)).Select
            ActiveSheet.Paste
        Next IND

End Sub

Sub commentCluster()

    On Error Resume Next

    If OpUnit = "Botswana" Then
        colSNU = WorksheetFunction.Match("Greater Gabarone Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Greater Gabarone Cluster: Gaborone District, Kgatleng District, Kweneng East District, South East District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Greater Francistown Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Greater Francistown Cluster: Francistown District, North East District, Tutume District"
        Cells(colSNU, 3).Comment.Visible = False
    End If

    If OpUnit = "Cameroon" Then
        colSNU = WorksheetFunction.Match("Yaounde Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Yaounde Cluster: Djoungolo, Nkolndongo, Biyem Assi, Cite Verte, Efoulan"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Doula Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Doula Cluster: Deido, Cite de Palmiers, Nylon, Bonnassama, New Bell, Logbaba, Mbangue"
        Cells(colSNU, 3).Comment.Visible = False
    End If


    If OpUnit = "Haiti" Then
        colSNU = WorksheetFunction.Match("Greater Port-au-Prince Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Greater Port-au-Prince Cluster: Port-au-Prince, Croix-Desbouquets, L??og??ne"
        Cells(colSNU, 3).Comment.Visible = False
    End If


    If OpUnit = "Mozambique" Then
        colSNU = WorksheetFunction.Match("Maputo City Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Maputo City Cluster: Kamavota, Kamaxakeni, Kampfumu, Kamubukwana, Kanyaka, Katembe, Nlhamankulu"
        Cells(colSNU, 3).Comment.Visible = False
    End If

    If OpUnit = "Uganda" Then
        colSNU = WorksheetFunction.Match("Kampala Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kampala Cluster: Wakiso District, Kampala District, Mukono District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Mbarara Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Mbarara Cluster: Mbarara District, Kiruhura District, Sheema District, Buhweju District, Ibanda District, Ntungamo District, Bushenyi District, Mitooma District, Rubirizi District, Rukungiri District, Kanungu District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Kabarole Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kabarole Cluster: Kabarole District, Kyenjojo District, Kamwenge District, Ntoroko District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Gulu Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Gulu Cluster: Gulu District, Nwoya District, Lamwo District, Pader District, Amuru District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Gulu Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Gulu Cluster: Gulu District, Nwoya District, Lamwo District, Pader District, Amuru District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Masaka Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Masaka Cluster: Masaka District, Rakai District, Lwengo District, Lyantonde District, Sembabule District, Bukomansimbi District, Kalungu District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Kabale Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kabale Cluster: Kabale District, Kisoro District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Soroti Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Soroti Cluster: Soroti District, Amuria District, Kaberamaido District, Serere District, Ngora District, Katakwi District"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Lira Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Lira Cluster: Lira District, Kole District, Otuke District, Alebtong District, Dokolo District, Amolatar District, Apac District"
        Cells(colSNU, 3).Comment.Visible = False

    End If

    If OpUnit = "Tanzania" Then
        colSNU = WorksheetFunction.Match("Arusha-Meru_Monduli Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Arusha-Meru_Monduli Cluster: Arusha CC, Arusha DC, Meru DC, Monduli DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Dar es Salaam-Bagamoyo-Kisarawe-Kibaha-Mkuranga Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Dar es Salaam-Bagamoyo-Kisarawe-Kibaha-Mkuranga Cluster: Bagamoyo DC, Ilala MC, Kibaha DC, Kibaha TC, Kinondoni MC, Kisarawe DC, Mkuranga DC, Temeke MC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Dodoma_Bahi_Chamwino-Manyoni Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Dodoma_Bahi_Chamwino-Manyoni Cluster: Bahi DC, Chamwino DC, Dodoma MC, Kiteto DC, Manyoni DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Geita Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Geita Cluster: Geita DC, Geita TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Handeni-Kilindi Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Handeni-Kilindi Cluster: Handeni DC, Handeni TC, Kilindi DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Iringa-Kilolo Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Iringa-Kilolo Cluster: Iringa DC, Iringa MC, Kilolo DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Kahama Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kahama Cluster: Kahama TC, Msalala DC, Ushetu DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Kasulu Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kasulu Cluster: Kasulu DC, Kasulu TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Kigoma Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kigoma Cluster: Kigoma DC, Kigoma Ujiji MC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Korogwe Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Korogwe Cluster: Korogwe DC, Korogwe TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Kyerwa-Missenyi Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Kyerwa-Missenyi Cluster: Kyerwa DC, Missenyi DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Lushoto Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Lushoto Cluster: Bumbuli DC, Lushoto DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Masasi Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Masasi Cluster: Masasi DC, Masasi TC, Nanyumbu DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Mbeya Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Mbeya Cluster: Busokelo DC, Mbarali DC, Mbeya CC, Mbeya DC, Rungwe DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Morogoro Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Morogoro Cluster: Morogoro DC, Morogoro MC, Mvomero DC"
        Cells(colSNU, 3).Comment.Visible = False


        colSNU = WorksheetFunction.Match("Moshi-Hai_Siha_Mwanga Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Moshi-Hai_Siha_Mwanga Cluster: Hai DC, Moshi DC, Moshi MC, Mwanga DC, Siha DC"
        Cells(colSNU, 3).Comment.Visible = False


        colSNU = WorksheetFunction.Match("Mpanda Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Mpanda Cluster: Mpanda DC, Mpanda TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Mtwara Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Mtwara Cluster: Mtwara DC, Mtwara Mikindani MC, Nanyumba TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Mufindi Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Mufindi Cluster: Mafinga TC, Mufindi DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Musoma Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Musoma Cluster: Bunda DC, Butiama DC, Musoma DC, Musoma MC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Mwanza Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Mwanza Cluster: Ilemela MC, Nyamagana MC, Sengerema DC, Ukerewe DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Njombe Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Njombe Cluster: Makambako TC, Njombe DC, Njombe TC, Wanging'ombe DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Nzega Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Nzega Cluster: Igunga DC, Nzega DC, Nzega TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Pemba Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Pemba Cluster: Chake Chake, Wete"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Shinyanga Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Shinyanga Cluster: Kishapu DC, Shinyanga DC, Shinyanga MC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Singida-Hanang-Ikungi Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Singida-Hanang-Ikungi Cluster: Hanang DC, Ikungi DC, Singida DC, Singida MC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Songea-Namtumbo Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Songea-Namtumbo Cluster: Namtumbo DC, Songea DC, Songea MC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Tabora-Uyui Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Tabora-Uyui Cluster: Tabora MC, Uyui DC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Tanga-Pangani-Muheza-Mkinga Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Tanga-Pangani-Muheza-Mkinga Cluster: Mkinga DC, Muheza DC, Pangani DC, Tanga CC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Tarime Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Tarime Cluster: Tarime DC, Tarime TC"
        Cells(colSNU, 3).Comment.Visible = False

        colSNU = WorksheetFunction.Match("Unguja/Zanziba Cluster", ActiveWorkbook.Sheets("DATIM Indicator Table").Range("C:C"), 0)
        Cells(colSNU, 3).AddComment "Unguja/Zanziba Cluster: Kaskazini A, Magharibi, Mjini"
        Cells(colSNU, 3).Comment.Visible = False
    End If

End Sub

Sub setupSNUs()
    'add SNU list to summary and targets and IM targeting tab
        shtNames = Array("Target Calculation", "SNU Targets for EA")
        For Each sht In shtNames
            Sheets(sht).Activate
            Range(Cells(5, 3), Cells(LastRow, 3)).FormulaR1C1 = "='DATIM Indicator Table'!RC"
            Range(Cells(4, 3), Cells(LastRow, 3)).Select
            Application.DisplayAlerts = False
            Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
            Application.DisplayAlerts = False
            Columns("C:C").ColumnWidth = 20.75
        Next sht
    'add SNU list, copy default values, and add named range to Assumption Input tab
        Sheets("Assumption Input").Activate
        LastColumn = Range("A2").CurrentRegion.Columns.Count
        Range(Cells(6, 3), Cells(LastRow, 3)).FormulaR1C1 = "='DATIM Indicator Table'!RC"
        Range(Cells(7, 4), Cells(7, LastColumn)).Select
        Selection.Copy
        Range(Cells(7, 4), Cells(LastRow, LastColumn)).Select
        ActiveSheet.Paste
        Range(Cells(4, 3), Cells(LastRow, LastColumn)).Select
        Application.DisplayAlerts = False
        Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
        Application.DisplayAlerts = False
        Columns("C:C").ColumnWidth = 20.75
        Range(Cells(4, 3), Cells(LastRow, LastColumn)).Select

End Sub
Sub setupHTCDistro()
    'add SNU list to HTC distro tab
        Sheets("HTC Target Calculation").Activate
        Range(Cells(5, 3), Cells(LastRow, 3)).FormulaR1C1 = "='DATIM Indicator Table'!RC"
        Range(Cells(4, 3), Cells(LastRow, 3)).Select
        Application.DisplayAlerts = False
        Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
        Application.DisplayAlerts = False
        Columns("C:C").ColumnWidth = 20.75
    'add total for ART to HTC distro tab
        Sheets("HTC Target Calculation").Activate
        For i = 5 To 12
            If i = 9 Then i = i + 1
            Cells(5, i).FormulaR1C1 = "=SUBTOTAL(109, R[2]C:R[" & LastRow - 5 & "]C)"
        Next i

    'add in extra named ranges
        INDnames = Array("T_htc_peds_need", "T_htc_adlt_need", "T_htc_need", "T_pos_ident", "T_eid_treat", "T_ped_treat", "T_htc_pos", "T_tx_curr_exp", "T_tx_curr_u15_exp", "T_htc_pitc", "T_htc_cbtc", "T_htc_vct", "T_htc_othped", "T_htc_ea")
        For Each IND In INDnames
            If IND = "T_pos_ident" Or IND = "T_eid_treat" Or IND = "T_ped_treat" Or IND = "T_tx_curr_exp" Or IND = "T_tx_curr_u15_exp" Then
                sht = "Target Calculation"
            Else
                sht = "HTC Target Calculation"
            End If
            Sheets(sht).Activate
            indColNum = WorksheetFunction.Match(IND, ActiveWorkbook.Sheets(sht).Range("2:2"), 0)
            Set indRng = Sheets(sht).Range(Cells(5, indColNum), Cells(LastRow, indColNum))
            ActiveWorkbook.Names.Add Name:=IND, RefersTo:=indRng
        Next IND

End Sub

Sub lookupsumFormulas()
    'copy lookup formulas to all SNUs
        shtNames = Array("HTC Target Calculation", "Target Calculation", "SNU Targets for EA")
        For Each sht In shtNames
            Sheets(sht).Select
            LastColumn = Sheets(sht).Range("C2").CurrentRegion.Columns.Count
            Range(Cells(7, 4), Cells(7, LastColumn)).Select
            If sht = "SNU Targets for EA" Then
                Selection.Replace what:="$21", Replacement:="$" & LastRow
            End If
            Selection.Copy
            Range(Cells(8, 4), Cells(LastRow, LastColumn)).Select
            Selection.PasteSpecial Paste:=xlPasteFormulasAndNumberFormats
            Selection.Font.Name = "Calibri Light"
            Application.CutCopyMode = False
        Next sht
    'add formula to totals
        shtNames = Array("HTC Target Calculation", "Target Calculation", "SNU Targets for EA", "Key Ind Trends")
        LastRowRC = LastRow - 5
        For Each sht In shtNames
            Sheets(sht).Select
            LastColumn = Sheets(sht).Range("A2").CurrentRegion.Columns.Count
            If sht = "Target Calculation" Then
                FirstColumn = 6
            Else
                FirstColumn = 4
            End If
            For i = FirstColumn To LastColumn
                If ActiveSheet.Cells(4, i).Value <> "" Then
                    Cells(5, i).Select
                    Selection.FormulaR1C1 = "=SUBTOTAL(109, R[1]C:R[" & LastRowRC & "]C)"
                    Selection.NumberFormat = "#,##0"
                End If
                If ActiveSheet.Cells(7, i).Style = "Percent" Then Cells(5, i).Value = ""
                If ActiveSheet.Cells(4, i).Value = "ART Coverage" Or ActiveSheet.Cells(4, i).Value = "ART Coverage (<15)" Then
                   Cells(7, i).Copy
                   Cells(5, i).Select
                   ActiveSheet.Paste
                End If

            Next i
        Next sht
End Sub

Sub sparkTrends()
    'tends sheet
        Sheets("Key Ind Trends").Activate
    'add named range for snulist
        Range(Cells(4, 3), Cells(LastRow, 3)).Select
        Application.DisplayAlerts = False
        Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
        Application.DisplayAlerts = True
    'delete subtotal for prioritization SNUs
        LastColumn = ActiveSheet.Range("A2").CurrentRegion.Columns.Count
        For i = 4 To LastColumn
            Cells(5, i).ClearContents
            i = i + 5
        Next
    'add in formula to lookup prioritization
        Range(Cells(7, 4), Cells(LastRow, 4)).Select
        Selection.FormulaR1C1 = "=IFERROR(INDEX(priority_snu,MATCH(snu_trend,snulist,0)),"""")"
    'add lookup formula for 2018 target
        For i = 9 To LastColumn
            IND = Cells(2, i).Value
            Range(Cells(7, i), Cells(LastRow, i)).Select
            If IND = "T_htc_need" Or IND = "T_htc_pos" Then
                Selection.Formula = "=IFERROR(INDEX(" & IND & ",MATCH(snu_trend,snu_htc,0)),"""")"
            Else
                colIND = WorksheetFunction.Match(IND, ActiveWorkbook.Sheets("Target Calculation").Range("4:4"), 0)
                Selection.FormulaR1C1 = "=IFERROR(INDEX('Target Calculation'!R5C" & colIND & ":R" & LastRow & "C" & colIND & ",MATCH(snu_trend,snu,0)),"""")"
            End If
            i = i + 5
        Next i

    'add sparklines
         Set spkGrp = Range("J7").SparklineGroups.Add(Type:=xlSparkLine, SourceData:="F7:I7")
         With spkGrp.SeriesColor
             .ThemeColor = 9
             '.TintAndShade = -0.249977111117893
         End With
         With spkGrp.Points.Markers
             .Visible = True
             .Color.ThemeColor = 9
             '.TintAndShade = -0.249977111117893
         End With
         Range("J7").Copy

        For i = 10 To LastColumn
             Cells(5, i).Select
             ActiveSheet.Paste
             Range(Cells(7, i), Cells(LastRow, i)).Select
             ActiveSheet.Paste
             i = i + 5
         Next i

End Sub
Sub format()
    'format
        For Each sht In shtNames
        Sheets(sht).Select
        If sht = "Allocation by IM" Or sht = "PBAC IM Targets" Then
            LastRow = Range("C1").CurrentRegion.Rows.Count
            End If
        LastColumn = Sheets(sht).Range("A2").CurrentRegion.Columns.Count
        'format - color Navigation pane (column A)
            Range(Cells(5, 1), Cells(LastRow, 1)).Select
            With Selection.Interior
                .Pattern = xlSolid
                .PatternColorIndex = xlAutomatic
                .ThemeColor = xlThemeColorAccent4
                .TintAndShade = 0.399975585192419
                .PatternTintAndShade = 0
            End With
        'format - indented SNUs
            Range(Cells(6, 3), Cells(LastRow, 3)).Select
            Selection.IndentLevel = 1
        'format - banded rows
            If sht = "PBAC IM Targets" Then
                FirstRow = 15
            Else
                FirstRow = 7
            End If
            With Range(Cells(FirstRow, 3), Cells(LastRow, LastColumn))
                .Activate
                .FormatConditions.Add xlExpression, Formula1:="=AND($C7<>"""",C$4<>"""",MOD(ROW(),2)=0)"
                With .FormatConditions(1).Interior
                    .Pattern = xlSolid
                    .PatternColorIndex = xlAutomatic
                    .ThemeColor = xlThemeColorAccent4
                    .TintAndShade = 0.799981688894314
                    .PatternTintAndShade = 0
                End With
            End With
            Range("A1").Select
        Next sht
End Sub

Sub formatHeaders()
    'format - color headers on DATIM Indicator Table
        Sheets("DATIM Indicator Table").Select
        IndicatorCount = Range("A4").CurrentRegion.Columns.Count 'find last column
        Range(Cells(3, 4), Cells(3, IndicatorCount)).Select
        With Selection.Interior
            .Pattern = xlSolid
            .PatternColorIndex = xlAutomatic
            .ThemeColor = xlThemeColorAccent2
            .TintAndShade = 0
            .PatternTintAndShade = 0
        End With
        Range(Cells(4, 4), Cells(4, IndicatorCount)).Select
        With Selection.Interior
            .Pattern = xlSolid
            .PatternColorIndex = xlAutomatic
            .ThemeColor = xlThemeColorAccent2
            .TintAndShade = 0.399975585192419
            .PatternTintAndShade = 0
        End With

End Sub

Sub showChanges()
    'add conditional formatting to identify changes in table
        shtNames = Array("HTC Target Calculation", "Assumption Input", "DATIM Indicator Table")
        For Each sht In shtNames
            Sheets(sht).Select
            Sheets(sht).Copy After:=Sheets(sht)
            If sht = "HTC Target Calculation" Then Sheets(sht & " (2)").Name = "dupHTCTargetCalc"
            If sht = "Assumption Input" Then Sheets(sht & " (2)").Name = "dupAssumptionInput"
            If sht = "DATIM Indicator Table" Then Sheets(sht & " (2)").Name = "dupIndicatorTable"
            LastColumn = Sheets(sht).Range("A2").CurrentRegion.Columns.Count
            Range(Cells(3, 4), Cells(LastRow, LastColumn)).Select
            If sht <> "HTC Target Calculation" Then
                Selection.Copy
                Selection.PasteSpecial Paste:=xlPasteValues
            End If
            Range("A1").Select
            Sheets(sht).Select
            Range("C5").Select
            If sht = "HTC Target Calculation" Then
                Range(Cells(5, 19), Cells(LastRow, LastColumn)).Select
            Else
                Range(Cells(5, 4), Cells(LastRow, LastColumn)).Select
            End If
            If sht <> "Assumption Input" Then
                With Selection
                    .Activate
                    If sht = "HTC Target Calculation" Then .FormatConditions.Add xlExpression, Formula1:="=S5<>dupHTCTargetCalc!S5"
                    If sht = "DATIM Indicator Table" Then .FormatConditions.Add xlExpression, Formula1:="=D5<>dupIndicatorTable!D5"
                    .FormatConditions(2).Interior.ThemeColor = xlThemeColorAccent3
                    .FormatConditions(2).priority = 1
                End With
            End If
            Range("C3").Select
        Next sht
    'hide duplicates
        Sheets(Array("dupIndicatorTable", "dupAssumptionInput", "dupHTCTargetCalc")).Visible = False
End Sub

Sub filters()
    'add filter rows
        For Each sht In shtNames
            Sheets(sht).Select
            IndicatorCount = Range("A2").CurrentRegion.Columns.Count
            Range(Cells(6, 3), Cells(6, IndicatorCount)).Select
                With Selection.Interior
                    .Pattern = xlSolid
                    .PatternColorIndex = xlAutomatic
                    .ThemeColor = xlThemeColorAccent4
                    .TintAndShade = 0.399975585192419
                    .PatternTintAndShade = 0
                End With
                Range(Cells(6, 3), Cells(LastRow, IndicatorCount)).Select
                Selection.AutoFilter
                Range("C6").NumberFormat = ";;;"
                Range("D1").Select
        Next sht
End Sub

Sub dimDefault()

    'conditional formatting - hide if manual entry values equal default
        Sheets("Assumption Input").Select
        IndicatorCount = Range("A2").CurrentRegion.Columns.Count
        Range(Cells(7, 6), Cells(LastRow, IndicatorCount)).Select
        With Selection
            .Activate
            .FormatConditions.Add xlExpression, Formula1:="=OR(F7=F$5,AND(F$5="""",F7=dupAssumptionInput!F7))"
            .FormatConditions(2).Font.ThemeColor = xlThemeColorDark1
            .FormatConditions(2).Font.TintAndShade = -0.499984740745262
            .FormatConditions(2).Interior.Pattern = xlNone
            .FormatConditions(2).Interior.TintAndShade = 0
            .FormatConditions(2).Interior.PatternTintAndShade = 0
            .FormatConditions(2).priority = 1
        End With
        With Range(Cells(7, 6), Cells(LastRow, IndicatorCount))
            .Activate
            .FormatConditions.Add xlExpression, Formula1:="=OR(AND(F7=F$5,MOD(ROW(),2)=0),AND(F$5="""",F7=dupAssumptionInput!F7,MOD(ROW(),2)=0))"
            With .FormatConditions(3).Font
                .ThemeColor = xlThemeColorDark1
                .TintAndShade = -0.499984740745262
            End With
            With .FormatConditions(3).Interior
                .Pattern = xlSolid
                .PatternColorIndex = xlAutomatic
                .ThemeColor = xlThemeColorAccent4
                .TintAndShade = 0.799981688894314
                .PatternTintAndShade = 0
            End With
            .FormatConditions(3).priority = 1
        End With
        Range("B1").Select
End Sub

Sub updateOutput()
'update SNU Targets for EA
    'loop over columns, check for formula, then loop over rows
     Sheets("SNU Targets for EA").Activate
     LastColumn = Range("A2").CurrentRegion.Columns.Count
        For i = 5 To LastColumn
        If Len(Trim(Cells(7, i).Value)) > 0 Then
            celltxt = ActiveSheet.Cells(7, i).Formula
            celltxt = Replace(celltxt, "20", LastRow)
            Cells(7, i).Formula = celltxt
        End If
        Next i
    Range(Cells(7, 4), Cells(7, LastColumn)).Copy
    Range(Cells(8, 4), Cells(LastRow, LastColumn)).Select
    ActiveSheet.Paste
    Application.CutCopyMode = False
    Range("D1").Select

End Sub

Sub saveFile()
    'save
        Sheets("Home").Activate
        Range("X1").Select
        fname_dp = OUcompl_fldr & OpUnit_ns & "COP17DataPack" & "v" & VBA.format(Now, "yyyy.mm.dd") & ".xlsx"
        Application.DisplayAlerts = False
        ActiveWorkbook.SaveAs fname_dp

    'keep data pack open?
        If view = "No" Then
            dpWkbk.Close
        End If

        Application.DisplayAlerts = True
End Sub

Sub imTargeting()

    'setup named range for im targeting tab
        Sheets("SNU Targets for EA").Activate
        Range(Cells(4, 3), Cells(LastRow, LastColumn)).Select
        Application.DisplayAlerts = False
        Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
        Application.DisplayAlerts = True
        Range("D1").Select

    'loop over each sheet, adding in data from global_psnu
        shtNames = Array("Allocation by IM", "PBAC IM Targets")
        For Each sht In shtNames
                Sheets(sht).Activate
            'find OU coordinates in IM list
                dataWkbk.Sheets(sht).Activate
                FirstRow = Range("A:A").Find(what:=OpUnit, After:=Range("A1")).Row
                LastRow = Range("A:A").Find(what:=OpUnit, After:=Range("A1"), searchdirection:=xlPrevious).Row
                LastColumn = Range("A1").CurrentRegion.Columns.Count
                If sht = "Allocation by IM" Then
                    FirstColumn = 3
                Else
                    FirstColumn = 2
                End If
            'select OU data from global file to copy to data pack
                Range(Cells(FirstRow, FirstColumn), Cells(LastRow, LastColumn)).Select
                Selection.Copy
            'copy the data and paste in the data pack
                dpWkbk.Activate
                Sheets(sht).Activate
                If sht = "Allocation by IM" Then
                    Range("C7").Select
                Else
                    Range("C15").Select
                End If
                Selection.PasteSpecial Paste:=xlPasteValues
                Application.CutCopyMode = False
        Next sht

    'setup/format IM distro tab
        Sheets("Allocation by IM").Activate
        LastRow = Range("C1").CurrentRegion.Rows.Count
        Range(Cells(5, 7), Cells(LastRow, 24)).Select
        'format to hide zeros
        Selection.NumberFormat = "0%;-0%;;"
        LastColumn = Range("B2").CurrentRegion.Columns.Count 'TOFIX
        Range(Cells(5, 25), Cells(LastRow, LastColumn)).Select
        Selection.NumberFormat = "#,##0;-#,##0;;"
        'add in formula to lookup prioritization
        Range(Cells(7, 4), Cells(LastRow, 4)).Select
        Selection.FormulaR1C1 = "=IFERROR(INDEX(priority_snu,MATCH(Dsnulist,snulist,0)),""NOT DEFINED"")"
        'named range
        Range(Cells(4, 3), Cells(LastRow, LastColumn)).Select
        Application.DisplayAlerts = False
        Selection.CreateNames Top:=True, Left:=False, Bottom:=False, Right:=False
        Application.DisplayAlerts = True
        'copy formulas down for target allocation
        Range(Cells(7, 25), Cells(7, LastColumn)).Select
        Selection.Copy
        Range(Cells(8, 25), Cells(LastRow, LastColumn)).Select
        Selection.PasteSpecial Paste:=xlPasteFormulasAndNumberFormats
        Application.CutCopyMode = False
        'add total
        Range(Cells(5, 7), Cells(5, LastColumn)).Select
        Selection.Formula = "=SUBTOTAL(109, G6:G" & LastRow & ")"


    'setup/format PBAC targeting tab
        Sheets("PBAC IM Targets").Activate
        LastRow = Range("C1").CurrentRegion.Rows.Count
        LastColumn = Range("B2").CurrentRegion.Columns.Count
        'add named range
        Set indRng = Sheets("PBAC IM Targets").Range(Cells(5, 4), Cells(LastRow, 4))
        ActiveWorkbook.Names.Add Name:="P_mech", RefersTo:=indRng
        Set indRng = Sheets("PBAC IM Targets").Range(Cells(4, 6), Cells(4, LastColumn))
        ActiveWorkbook.Names.Add Name:="P_indtype", RefersTo:=indRng
        'copy formula from first IM row down
        Range(Cells(15, 6), Cells(15, LastColumn)).Select
        Selection.NumberFormat = "#,##0;-#,##0;;"
        Selection.Copy
        Range(Cells(15, 6), Cells(LastRow, LastColumn)).Select
        Selection.PasteSpecial Paste:=xlPasteFormulasAndNumberFormats
        Application.CutCopyMode = False
        'add total
        Range(Cells(5, 6), Cells(5, LastColumn)).Select
        Selection.Formula = "=SUBTOTAL(109, F14:F" & LastRow & ")"
        Selection.NumberFormat = "#,##0;-#,##0;;"
End Sub

Sub imshowChanges()
    'show changes
        Sheets("Allocation by IM").Select
        Sheets("Allocation by IM").Copy After:=Sheets("Allocation by IM")
        Sheets("Allocation by IM (2)").Name = "dupAllocationIM"
        LastRow = Range("C1").CurrentRegion.Rows.Count
        Range("A1").Select
        Sheets("Allocation by IM").Select
        Range("G5").Select
        Range(Cells(5, 7), Cells(LastRow, 24)).Select
        With Selection
            .Activate
            .FormatConditions.Add xlExpression, Formula1:="=G5<>dupAllocationIM!G5"
            .FormatConditions(2).Interior.ThemeColor = xlThemeColorAccent3
            .FormatConditions(2).priority = 1
        End With
        Range("C3").Select
    'hide duplicates
        Sheets("dupAllocationIM").Visible = False
End Sub

''''''''''''''''''''
''   Zip Folder   ''
''''''''''''''''''''
'Source: http://www.rondebruin.nl/win/s7/win001.htm

Sub Zip_All_Files_in_Folder()
'ABOUT: This sub zips the OU folder that contains the _
data pack and its supplementary files"

    Dim FileNameZip, FolderName
    Dim strDate As String, DefPath As String
    Dim oApp As Object

        DefPath = compl_fldr
        If Right(DefPath, 1) <> "\" Then
            DefPath = DefPath & "\"
        End If

        FolderName = OUcompl_fldr

        strDate = VBA.format(Now, "yyyy.mm.dd")
        FileNameZip = DefPath & OpUnit_ns & strDate & ".zip"

    'Create empty Zip File
        NewZip (FileNameZip)

        Set oApp = CreateObject("Shell.Application")
    'Copy the files to the compressed folder
        oApp.Namespace(FileNameZip).CopyHere oApp.Namespace(FolderName).items

    'Keep script waiting until Compressing is done
        On Error Resume Next
        Do Until oApp.Namespace(FileNameZip).items.Count = _
           oApp.Namespace(FolderName).items.Count
            Application.Wait (Now + TimeValue("0:00:01"))
        Loop
        On Error GoTo 0


End Sub

Sub NewZip(sPath)
    'Create empty Zip File
    'Changed by keepITcool Dec-12-2005
    If Len(Dir(sPath)) > 0 Then Kill sPath
        Open sPath For Output As #1
    Print #1, Chr$(80) & Chr$(75) & Chr$(5) & Chr$(6) & String(18, 0)
    Close #1
End Sub


Function bIsBookOpen(ByRef szBookName As String) As Boolean
    ' Rob Bovey
    On Error Resume Next
    bIsBookOpen = Not (Application.Workbooks(szBookName) Is Nothing)
End Function


Function Split97(sStr As Variant, sdelim As String) As Variant
    'Tom Ogilvy
    Split97 = Evaluate("{""" & _
    Application.Substitute(sStr, sdelim, """,""") & """}")
End Function
