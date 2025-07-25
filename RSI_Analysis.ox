#include <oxstd.h>

// Calculate moving average
MovingAverage(const vPrices, const iPeriod)
{
    decl iRows, vMA, i;
    iRows = rows(vPrices);
    vMA = zeros(iRows, 1);
    
    for (i = iPeriod - 1; i < iRows; ++i)
    {
        vMA[i] = meanc(vPrices[i-iPeriod+1:i]);
    }
    return vMA;
}

// Detect stock splits
DetectStockSplits(const vPrices, const dThreshold)
{
    decl vSplits, i, price_change_pct;
    vSplits = {};
    
    for (i = 1; i < rows(vPrices); ++i)
    {
        if (vPrices[i-1] > 0 && vPrices[i] > 0)
        {
            price_change_pct = (vPrices[i] - vPrices[i-1]) / vPrices[i-1] * 100;
            if (price_change_pct < -dThreshold)
            {
                vSplits = vSplits | i;
            }
        }
    }
    return vSplits;
}

// Detect crossover events
DetectCrossovers(const vPrices, const vMA_Short, const vMA_Long, const iStartDay, const iEvalDays)
{
    decl mCrossovers, i, cross_count;
    decl prev_diff, curr_diff;
    
    cross_count = 0;
    mCrossovers = zeros(1000, 4); // [day, type, price_before, return_pct]
    
    for (i = iStartDay; i < rows(vMA_Short) - iEvalDays; ++i)
    {
        if (vMA_Short[i-1] > 0 && vMA_Short[i] > 0 && vMA_Long[i-1] > 0 && vMA_Long[i] > 0)
        {
            prev_diff = vMA_Short[i-1] - vMA_Long[i-1];
            curr_diff = vMA_Short[i] - vMA_Long[i];
            
            decl cross_type = 0;
            if (prev_diff <= 0 && curr_diff > 0)
                cross_type = 1; // Golden cross
            else if (prev_diff >= 0 && curr_diff < 0)
                cross_type = -1; // Death cross
            
            if (cross_type != 0)
            {
                decl price_before = vPrices[i];
                decl price_after = vPrices[i + iEvalDays];
                decl return_pct = 100 * (price_after - price_before) / price_before;
                
                mCrossovers[cross_count][] = i ~ cross_type ~ price_before ~ return_pct;
                cross_count++;
                
                if (cross_count >= 1000) break;
            }
        }
    }
    
    if (cross_count > 0)
        return mCrossovers[0:cross_count-1][];
    else
        return zeros(0, 4);
}

// Calculate statistics for a specific window
CalculateWindowStats(const mCrossovers, const iStart, const iEnd)
{
    decl i, total_crosses, golden_crosses, death_crosses;
    decl golden_correct, death_correct, accuracy, score;
    
    total_crosses = 0;
    golden_crosses = 0;
    death_crosses = 0;
    golden_correct = 0;
    death_correct = 0;
    
    for (i = 0; i < rows(mCrossovers); ++i)
    {
        decl cross_day = mCrossovers[i][0];
        if (cross_day >= iStart && cross_day <= iEnd)
        {
            total_crosses++;
            decl cross_type = mCrossovers[i][1];
            decl return_pct = mCrossovers[i][3];
            
            if (cross_type == 1) // Golden cross
            {
                golden_crosses++;
                if (return_pct > 0) golden_correct++;
            }
            else // Death cross
            {
                death_crosses++;
                if (return_pct < 0) death_correct++;
            }
        }
    }
    
    if (total_crosses > 0)
    {
        accuracy = (golden_correct + death_correct) * 100.0 / total_crosses;
        score = accuracy + log(total_crosses + 1) * 5; // Bonus for more signals
    }
    else
    {
        accuracy = 0;
        score = 0;
    }
    
    return total_crosses ~ golden_crosses ~ death_crosses ~ accuracy ~ score;
}

// Analyze windows between splits for single asset
AnalyzeAssetWindows(const vSplits, const mCrossovers, const iMinWindowDays, const iMaxDays, const iLongMA)
{
    decl mWindows, window_count, i;
    decl window_start, window_end, window_length;
    
    window_count = 0;
    mWindows = zeros(100, 8); // [start, end, length, total_crosses, golden_crosses, death_crosses, accuracy, score]
    
    // Add window from start to first split
    if (sizerc(vSplits) > 0)
    {
        window_start = iLongMA; // Start when long MA becomes valid
        window_end = vSplits[0] - 1;
        window_length = window_end - window_start + 1;
        
        if (window_length >= iMinWindowDays)
        {
            decl window_stats = CalculateWindowStats(mCrossovers, window_start, window_end);
            mWindows[window_count][] = window_start ~ window_end ~ window_length ~ 
                                      window_stats[0] ~ window_stats[1] ~ window_stats[2] ~ 
                                      window_stats[3] ~ window_stats[4];
            window_count++;
        }
    }
    
    // Add windows between splits
    for (i = 0; i < sizerc(vSplits) - 1; ++i)
    {
        // Start after split + long MA period to avoid contaminated moving averages
        window_start = vSplits[i] + 1 + iLongMA;
        window_end = vSplits[i+1] - 1;
        window_length = window_end - window_start + 1;
        
        if (window_length >= iMinWindowDays)
        {
            decl window_stats = CalculateWindowStats(mCrossovers, window_start, window_end);
            mWindows[window_count][] = window_start ~ window_end ~ window_length ~ 
                                      window_stats[0] ~ window_stats[1] ~ window_stats[2] ~ 
                                      window_stats[3] ~ window_stats[4];
            window_count++;
        }
    }
    
    // Add window from last split to end
    if (sizerc(vSplits) > 0)
    {
        // Start after split + long MA period to avoid contaminated moving averages
        window_start = vSplits[sizerc(vSplits)-1] + 1 + iLongMA;
        window_end = iMaxDays;
        window_length = window_end - window_start + 1;
        
        if (window_length >= iMinWindowDays)
        {
            decl window_stats = CalculateWindowStats(mCrossovers, window_start, window_end);
            mWindows[window_count][] = window_start ~ window_end ~ window_length ~ 
                                      window_stats[0] ~ window_stats[1] ~ window_stats[2] ~ 
                                      window_stats[3] ~ window_stats[4];
            window_count++;
        }
    }
    
    // If no splits found, create one big window
    if (window_count == 0 && sizerc(vSplits) == 0)
    {
        window_start = iLongMA;
        window_end = iMaxDays;
        window_length = window_end - window_start + 1;
        
        if (window_length >= iMinWindowDays)
        {
            decl window_stats = CalculateWindowStats(mCrossovers, window_start, window_end);
            mWindows[window_count][] = window_start ~ window_end ~ window_length ~ 
                                      window_stats[0] ~ window_stats[1] ~ window_stats[2] ~ 
                                      window_stats[3] ~ window_stats[4];
            window_count++;
        }
    }
    
    if (window_count > 0)
        return mWindows[0:window_count-1][];
    else
        return zeros(0, 8);
}

// Find best window for a single asset
FindBestWindow(const mWindows)
{
    decl best_score, best_idx, i;
    
    if (rows(mWindows) == 0)
        return zeros(1, 8);
    
    best_score = -1;
    best_idx = 0;
    
    for (i = 0; i < rows(mWindows); ++i)
    {
        if (mWindows[i][7] > best_score) // score is column 7
        {
            best_score = mWindows[i][7];
            best_idx = i;
        }
    }
    
    return mWindows[best_idx][];
}

// Analyze single asset and return best window info
AnalyzeSingleAsset(const mData, const iAssetIdx, const iShortMA, const iLongMA, const iEvalDays, const dSplitThreshold, const iMinWindowDays)
{
    decl vPrices = mData[][iAssetIdx];
    
    // Calculate moving averages
    decl vMA_Short = MovingAverage(vPrices, iShortMA);
    decl vMA_Long = MovingAverage(vPrices, iLongMA);
    
    // Detect splits and crossovers
    decl vSplits = DetectStockSplits(vPrices, dSplitThreshold);
    decl mCrossovers = DetectCrossovers(vPrices, vMA_Short, vMA_Long, iLongMA, iEvalDays);
    
    // Analyze windows
    decl mWindows = AnalyzeAssetWindows(vSplits, mCrossovers, iMinWindowDays, rows(vPrices)-iEvalDays, iLongMA);
    decl best_window = FindBestWindow(mWindows);
    
    // Return: [asset_idx, start, end, length, total_crosses, golden_crosses, death_crosses, accuracy, score, num_splits]
    if (rows(best_window) > 0 && best_window[7] > 0) // Check if valid window found
        return iAssetIdx ~ best_window ~ sizerc(vSplits);
    else
        return iAssetIdx ~ zeros(1, 8) ~ sizerc(vSplits);
}

// Export batch analysis results
ExportBatchResults(const mResults, const iShortMA, const iLongMA)
{
    decl csv_filename = "BatchAnalysis_MA" + sprint(iShortMA) + "_MA" + sprint(iLongMA) + ".csv";
    decl file = fopen(csv_filename, "w");
    
    if (file)
    {
        fprintln(file, "Asset,Asset_Name,Start_Day,End_Day,Length_Days,Total_Crosses,Golden_Crosses,Death_Crosses,Accuracy_Percent,Score,Num_Splits");
        
        for (decl i = 0; i < rows(mResults); ++i)
        {
            decl asset_idx = mResults[i][0];
            decl asset_name = "aan" + sprint(asset_idx + 1);
            
            fprintln(file, asset_idx + 1, ",", asset_name, ",", mResults[i][1], ",", mResults[i][2], ",", mResults[i][3], ",",
                    mResults[i][4], ",", mResults[i][5], ",", mResults[i][6], ",", 
                    mResults[i][7], ",", mResults[i][8], ",", mResults[i][9]);
        }
        
        fclose(file);
        println("Batch analysis results exported to: ", csv_filename);
    }
    else
    {
        println("Error: Could not create ", csv_filename);
    }
}

// Display top performing assets
DisplayTopAssets(const mResults, const iTopN)
{
    decl mSorted, vIndices, i, j;
    
    // Sort by score (column 8) in descending order
    vIndices = sortcindex(mResults[][8]);
    
    // Manually reverse the indices for descending order
    decl vReversed = zeros(rows(vIndices), 1);
    for (i = 0; i < rows(vIndices); ++i)
    {
        vReversed[i] = vIndices[rows(vIndices) - 1 - i];
    }
    
    mSorted = mResults[vReversed][];
    
    println("\n=== TOP ", iTopN, " PERFORMING ASSETS ===");
    println("Rank\tAsset\tStart\tEnd\tLength\tCrosses\tAccuracy\tScore\tSplits");
    println("-"*80);
    
    decl rank = 1;
    for (i = 0; i < min(iTopN, rows(mSorted)); ++i)
    {
        if (mSorted[i][8] > 0) // Only show assets with valid windows
        {
            println(rank, "\taan", mSorted[i][0]+1, "\t", mSorted[i][1], "\t", mSorted[i][2], "\t", 
                   mSorted[i][3], "\t", mSorted[i][4], "\t", mSorted[i][7], "%\t", 
                   mSorted[i][8], "\t", mSorted[i][9]);
            rank++;
        }
    }
}

// Main batch analysis function
main()
{
    // === CONFIGURATION PARAMETERS ===
    decl iShortMA = 70;         // Short-term moving average period
    decl iLongMA = 260;         // Long-term moving average period
    decl iEvalDays = 10;         // Days to evaluate signal performance
    decl dSplitThreshold = 30.0; // Threshold for detecting splits (% price drop)
    decl iMinWindowDays = 200;   // Minimum window length (about 9 months)
    decl iTopN = 10;            // Number of top assets to display
    
    println("=== BATCH ANALYSIS FOR ALL ASSETS ===");
    println("Moving Averages: ", iShortMA, "-day vs ", iLongMA, "-day");
    println("Evaluation Period: ", iEvalDays, " days");
    println("Split Threshold: ", dSplitThreshold, "%");
    println("Minimum Window: ", iMinWindowDays, " days");
    println("MA Buffer After Split: ", iLongMA, " days");
    
    // Load data
    println("\nLoading data...");
    decl mData = loadmat("pdatau.prn");
    if (rows(mData) == 0)
    {
        println("Error: Could not load data");
        return;
    }
    
    println("Data loaded: ", rows(mData), " data points, ", columns(mData), " assets");
    
    // Analyze all assets
    println("Analyzing all assets...");
    decl mResults = zeros(19, 10); // [asset_idx, start, end, length, total_crosses, golden_crosses, death_crosses, accuracy, score, num_splits]
    
    for (decl i = 0; i < 19; ++i)
    {
        print("Processing asset aan", i+1, "... ");
        decl result = AnalyzeSingleAsset(mData, i, iShortMA, iLongMA, iEvalDays, dSplitThreshold, iMinWindowDays);
        mResults[i][] = result;
        
        if (result[8] > 0)
            println("Score: ", result[8]);
        else
            println("No valid windows found");
    }
    
    // Display results
    DisplayTopAssets(mResults, iTopN);
    
    // Export to CSV
    println("\nExporting batch results to CSV...");
    ExportBatchResults(mResults, iShortMA, iLongMA);
    
    println("\nBatch analysis complete!");
} 
