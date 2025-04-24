import UIKit
import DGCharts

class ChartManager {
    // The chart view being managed
    private weak var barChartView: BarChartView?
    
    // Chart data
    private var barChartValues = [BarChartDataEntry]()
    private var chartDataSet: BarChartDataSet?
    private var chartData: BarChartData?
    
    // MARK: - Initialization
    
    init(chartView: BarChartView) {
        self.barChartView = chartView
        setupChart()
    }
    
    // MARK: - Chart Setup
    
    private func setupChart() {
        guard let barChartView = barChartView else { return }
        
        // Initialize empty histogram data (256 values for each possible grayscale intensity)
        self.barChartValues = (0..<256).map { (i) -> BarChartDataEntry in
            return BarChartDataEntry(x: Double(i), y: 0)
        }
        
        // Setup chart dataset
        self.chartDataSet = BarChartDataSet(entries: self.barChartValues, label: "Histogram")
        self.chartDataSet?.drawValuesEnabled = false
        self.chartDataSet?.colors = [NSUIColor.white]
        self.chartData = BarChartData(dataSet: self.chartDataSet!)
        
        // Apply chart data
        barChartView.data = self.chartData
        
        // Configure X axis
        barChartView.xAxis.labelTextColor = .white
        barChartView.xAxis.drawLabelsEnabled = false
        barChartView.xAxis.labelPosition = .bottom
        barChartView.xAxis.axisMinimum = -5
        barChartView.xAxis.axisMaximum = 260
        
        // Configure chart appearance
        barChartView.drawGridBackgroundEnabled = false
        barChartView.drawBordersEnabled = true
        barChartView.borderColor = .white
        barChartView.gridBackgroundColor = .clear
        barChartView.backgroundColor = .clear
        
        // Configure left axis
        barChartView.leftAxis.gridColor = .clear
        barChartView.leftAxis.drawLabelsEnabled = false
        barChartView.leftAxis.drawAxisLineEnabled = false
        barChartView.leftAxis.axisLineWidth = 0
        barChartView.leftAxis.labelTextColor = .white
        
        // Configure right axis
        barChartView.rightAxis.gridColor = .clear
        barChartView.rightAxis.drawLabelsEnabled = false
        barChartView.rightAxis.drawAxisLineEnabled = false
        barChartView.rightAxis.axisLineWidth = 0
        
        // Additional settings
        barChartView.autoScaleMinMaxEnabled = true
        barChartView.legend.enabled = false
    }
    
    // MARK: - Chart Updates
    
    /// Update the chart with new histogram data percentages
    func updateChart(with percentages: [Double]) {
        guard percentages.count == 256, let barChartView = barChartView else { return }
        
        // Update chart data entries
        for index in 0..<256 {
            self.barChartValues[index].x = Double(index)
            self.barChartValues[index].y = percentages[index]
        }
        
        // Create new dataset and update chart
        let newDataSet = BarChartDataSet(entries: self.barChartValues, label: "Histogram")
        newDataSet.drawValuesEnabled = false
        newDataSet.colors = [NSUIColor.white]
        
        let newChartData = BarChartData(dataSet: newDataSet)
        
        // Update chart on main thread
        DispatchQueue.main.async { [weak self] in
            barChartView.data = newChartData
            barChartView.notifyDataSetChanged()
            self?.chartDataSet = newDataSet
            self?.chartData = newChartData
        }
    }
    
    /// Set the visibility of the chart
    func setChartVisible(_ visible: Bool) {
        barChartView?.isHidden = !visible
    }
    
    /// Get the current visibility status of the chart
    func isChartVisible() -> Bool {
        return !(barChartView?.isHidden ?? true)
    }
} 
