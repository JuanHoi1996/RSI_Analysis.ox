#include <oxstd.h>

// Function to calculate N-day Relative Strength Index (RSI)
CalculateRSI(const vPrices, const iN)
{
    decl iRows, vRSI, vPriceChanges, vGains, vLosses;
    decl i, avgGain, avgLoss, RS;
    
    iRows = rows(vPrices);
    vRSI = zeros(iRows, 1);
    vPriceChanges = zeros(iRows, 1);
    vGains = zeros(iRows, 1);
    vLosses = zeros(iRows, 1);
    
    // Calculate price changes
    for (i = 1; i < iRows; ++i)
    {
        if (vPrices[i-1] > 0 && vPrices[i] > 0)
        {
            vPriceChanges[i] = vPrices[i] - vPrices[i-1];
            
            if (vPriceChanges[i] > 0)
                vGains[i] = vPriceChanges[i];
            else
                vLosses[i] = -vPriceChanges[i]; // Store as positive value
        }
    }
    
    // Calculate RSI starting from day N
    for (i = iN; i < iRows; ++i)
    {
        // Calculate average gain and loss over N periods
        avgGain = meanc(vGains[i-iN+1:i]);
        avgLoss = meanc(vLosses[i-iN+1:i]);
        
        if (avgLoss > 0)
        {
            RS = avgGain / avgLoss;
            vRSI[i] = 100 - (100 / (1 + RS));
        }
        else if (avgGain > 0)
        {
            vRSI[i] = 100; // All gains, no losses
        }
        else
        {
            vRSI[i] = 50; // No change
        }
    }
    
    return vRSI;
}

// Function to export RSI data to CSV
ExportRSIToCSV(const vPrices, const vRSI, const iAssetIdx)
{
    decl csv_filename, csv_file, i;
    
    // Create filename for this asset
    csv_filename = sprint("Asset_", iAssetIdx, "_RSI_Data.csv");
    
    // Open CSV file for writing
    csv_file = fopen(csv_filename, "w");
    
    if (csv_file)
    {
        // Write header
        fprint(csv_file, "Day,Price,RSI\n");
        
        // Write data starting from day 30 (when RSI becomes valid)
        for (i = 30; i < rows(vPrices); ++i)
        {
            if (vPrices[i] > 0) // Valid price data
            {
                fprint(csv_file, i, ",", vPrices[i], ",", vRSI[i], "\n");
            }
        }
        
        fclose(csv_file);
        print("Asset ", iAssetIdx, " data exported to: ", csv_filename, "\n");
        return 1; // Success
    }
    else
    {
        print("Error: Could not create ", csv_filename, "\n");
        return 0; // Failed
    }
}

// Main function
main()
{
    decl mData, vAsset, vRSI;
    decl iAssets, iRows, i;
    decl iN = 30; // N-day RSI period
    decl successful_exports;
    
    print("Loading data from pdatau.prn...\n");
    
    // Load the data
    mData = loadmat("pdatau.prn");
    iRows = rows(mData);
    iAssets = columns(mData);
    
    print("Data loaded: ", iRows, " days, ", iAssets, " assets\n");
    print("Calculating ", iN, "-day RSI for all assets...\n\n");
    
    // Create output file for summary
    decl output_file = fopen("RSI_Analysis.out", "w");
    fprint(output_file, "30-Day Relative Strength Index (RSI) Analysis\n");
    fprint(output_file, "==============================================\n\n");
    fprint(output_file, "RSI Period: ", iN, " days\n");
    fprint(output_file, "Total Assets: ", iAssets, "\n");
    fprint(output_file, "Data Points per Asset: ", iRows, "\n");
    fprint(output_file, "Valid RSI Values: From day ", iN, " to ", iRows-1, "\n\n");
    
    successful_exports = 0;
    
    // Process each asset
    for (i = 0; i < iAssets; ++i)
    {
        print("Processing Asset ", i+1, "...\n");
        
        vAsset = mData[][i]; // Extract price data for asset i
        vRSI = CalculateRSI(vAsset, iN);
        
        // Export to CSV
        if (ExportRSIToCSV(vAsset, vRSI, i+1))
        {
            successful_exports++;
            
            // Write to summary file
            fprint(output_file, "Asset ", i+1, ": CSV exported successfully\n");
        }
        else
        {
            fprint(output_file, "Asset ", i+1, ": CSV export failed\n");
        }
    }
    
    // Overall summary
    print("\n==============================================\n");
    print("EXPORT SUMMARY\n");
    print("==============================================\n");
    print("Total Assets Processed: ", iAssets, "\n");
    print("Successful CSV Exports: ", successful_exports, "\n");
    print("Failed Exports: ", iAssets - successful_exports, "\n");
    
    fprint(output_file, "\n==============================================\n");
    fprint(output_file, "EXPORT SUMMARY\n");
    fprint(output_file, "==============================================\n");
    fprint(output_file, "Total Assets Processed: ", iAssets, "\n");
    fprint(output_file, "Successful CSV Exports: ", successful_exports, "\n");
    fprint(output_file, "Failed Exports: ", iAssets - successful_exports, "\n");
    
    fclose(output_file);
    
    print("\nAnalysis complete!\n");
    print("Summary saved to: RSI_Analysis.out\n");
    print("CSV files saved as: Asset_[N]_RSI_Data.csv\n");
    
    return 0;
} 