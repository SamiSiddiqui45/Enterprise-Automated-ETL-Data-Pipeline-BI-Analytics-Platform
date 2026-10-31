"""
src/dashboard.py
Enterprise Interactive BI Analytics Platform
Connected live to Microsoft SQL Server Data Warehouse (AnalyticsDW on .\\SQLEXPRESS)
Built with Streamlit & Plotly.
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from src.config import get_db_connection

# Page configuration
st.set_page_config(
    page_title="Enterprise BI Analytics Platform",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Custom Styling
st.markdown("""
<style>
    .main-title {
        font-size: 2.2rem;
        font-weight: 700;
        color: #1E293B;
        margin-bottom: 0.2rem;
    }
    .subtitle {
        font-size: 1.0rem;
        color: #64748B;
        margin-bottom: 1.5rem;
    }
    div[data-testid="stMetricValue"] {
        font-size: 1.8rem;
        font-weight: 700;
    }
    .kpi-card {
        background-color: #F8FAFC;
        border-radius: 8px;
        padding: 15px;
        border: 1px solid #E2E8F0;
    }
</style>
""", unsafe_allow_html=True)


@st.cache_data(ttl=300)
def load_analytics_data() -> pd.DataFrame:
    """Fetches denormalized fact and dimension records from AnalyticsDW for high-speed dashboard slicing."""
    conn = get_db_connection()
    query = """
    SELECT 
        f.FactSalesKey,
        f.SourceRowID,
        f.OrderID,
        f.SalesAmount,
        f.Quantity,
        f.DiscountRate,
        f.ProfitAmount,
        f.CalculatedCost,
        f.ProfitMargin,
        f.ShippingDurationDays,
        d.DateKey,
        d.FullDate,
        d.[Year],
        d.[Month],
        d.MonthName,
        d.YearMonth,
        c.CustomerID,
        c.CustomerName,
        c.CustomerSegment,
        p.ProductID,
        p.ProductName,
        p.Category,
        p.SubCategory,
        g.PostalCode,
        g.City,
        g.[State],
        g.Region,
        g.Country,
        s.ShipModeName
    FROM dw.FactSales f
    JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
    JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
    JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
    JOIN dw.DimGeography g ON f.GeographyKey = g.GeographyKey
    JOIN dw.DimShipMode s ON f.ShipModeKey = s.ShipModeKey;
    """
    df = pd.read_sql(query, conn)
    conn.close()
    df["FullDate"] = pd.to_datetime(df["FullDate"])
    return df


# Load data
with st.spinner("Connecting to SQL Server (AnalyticsDW)..."):
    try:
        raw_df = load_analytics_data()
    except Exception as e:
        st.error(f"❌ Failed to load data from SQL Server: {e}")
        st.info("Make sure the SQL Server service `MSSQL$SQLEXPRESS` is running and the ETL pipeline has executed.")
        st.stop()

# ============================================================================
# SIDEBAR: NAVIGATION & GLOBAL FILTERS
# ============================================================================
st.sidebar.image("https://img.icons8.com/fluency/96/data-configuration.png", width=70)
st.sidebar.title("BI Navigation")
page = st.sidebar.radio(
    "Select Report Page:",
    ["📈 Executive Overview", "📦 Product & Sales Analysis", "👥 Customer Analytics"],
)

st.sidebar.markdown("---")
st.sidebar.subheader("Global Filters (Slicers)")

# Year Slicer
available_years = sorted(raw_df["Year"].unique().tolist())
selected_years = st.sidebar.multiselect("Select Year(s):", available_years, default=available_years)

# Region Slicer
available_regions = sorted(raw_df["Region"].unique().tolist())
selected_regions = st.sidebar.multiselect("Select Region(s):", available_regions, default=available_regions)

# Segment Slicer
available_segments = sorted(raw_df["CustomerSegment"].unique().tolist())
selected_segments = st.sidebar.multiselect("Select Customer Segment:", available_segments, default=available_segments)

# Apply Filters
filtered_df = raw_df[
    (raw_df["Year"].isin(selected_years)) &
    (raw_df["Region"].isin(selected_regions)) &
    (raw_df["CustomerSegment"].isin(selected_segments))
]

st.sidebar.markdown("---")
st.sidebar.caption("🟢 **Database:** `.\\SQLEXPRESS` -> `AnalyticsDW`")
st.sidebar.caption(f"📊 **Loaded Records:** {len(filtered_df):,} / {len(raw_df):,}")

# Safeguard against empty filter selection
if filtered_df.empty:
    st.warning("⚠️ No records match the current filter selection. Please broaden your slicer options in the sidebar.")
    st.stop()

# ============================================================================
# PAGE 1: EXECUTIVE OVERVIEW
# ============================================================================
if page == "📈 Executive Overview":
    st.markdown('<div class="main-title">Executive Overview</div>', unsafe_allow_html=True)
    st.markdown('<div class="subtitle">High-level financial performance, revenue trajectory, and regional distribution.</div>', unsafe_allow_html=True)

    # Top KPI Banner
    total_sales = filtered_df["SalesAmount"].sum()
    total_profit = filtered_df["ProfitAmount"].sum()
    margin_pct = (total_profit / total_sales * 100) if total_sales > 0 else 0.0
    total_orders = filtered_df["OrderID"].nunique()
    aov = (total_sales / total_orders) if total_orders > 0 else 0.0

    kpi1, kpi2, kpi3, kpi4, kpi5 = st.columns(5)
    kpi1.metric("Total Revenue", f"${total_sales:,.2f}", delta=f"{len(filtered_df):,} lines")
    kpi2.metric("Total Profit", f"${total_profit:,.2f}", delta=f"{margin_pct:.1f}% Margin")
    kpi3.metric("Profit Margin %", f"{margin_pct:.2f}%", delta="Target: >10%")
    kpi4.metric("Total Orders", f"{total_orders:,}")
    kpi5.metric("Avg Order Value (AOV)", f"${aov:,.2f}")

    st.markdown("---")

    # Row 1: Monthly Sales & Profit Trend (Dual Axis)
    col_chart1, col_chart2 = st.columns([2, 1])

    with col_chart1:
        st.subheader("Monthly Sales Revenue & Profit Trend")
        monthly_trend = (
            filtered_df.groupby(["Year", "Month", "YearMonth"])
            .agg(MonthlySales=("SalesAmount", "sum"), MonthlyProfit=("ProfitAmount", "sum"))
            .reset_index()
            .sort_values(by=["Year", "Month"])
        )

        fig_trend = go.Figure()
        fig_trend.add_trace(go.Bar(
            x=monthly_trend["YearMonth"],
            y=monthly_trend["MonthlySales"],
            name="Sales Revenue ($)",
            marker_color="#2563EB",
            opacity=0.85,
        ))
        fig_trend.add_trace(go.Scatter(
            x=monthly_trend["YearMonth"],
            y=monthly_trend["MonthlyProfit"],
            name="Net Profit ($)",
            mode="lines+markers",
            line=dict(color="#10B981", width=3),
            yaxis="y2"
        ))

        fig_trend.update_layout(
            height=380,
            margin=dict(l=20, r=20, t=30, b=30),
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
            yaxis=dict(title="Revenue ($)", showgrid=True),
            yaxis2=dict(title="Profit ($)", overlaying="y", side="right", showgrid=False),
            xaxis=dict(tickangle=-45),
        )
        st.plotly_chart(fig_trend, use_container_width=True)

    with col_chart2:
        st.subheader("Sales by Customer Segment")
        segment_df = (
            filtered_df.groupby("CustomerSegment")["SalesAmount"]
            .sum()
            .reset_index()
        )
        fig_segment = px.pie(
            segment_df,
            values="SalesAmount",
            names="CustomerSegment",
            hole=0.45,
            color_discrete_sequence=["#3B82F6", "#10B981", "#F59E0B"],
        )
        fig_segment.update_traces(textposition="inside", textinfo="percent+label")
        fig_segment.update_layout(height=380, margin=dict(l=10, r=10, t=30, b=30), showlegend=False)
        st.plotly_chart(fig_segment, use_container_width=True)

    # Row 2: Regional Performance & Order Distribution
    col_reg1, col_reg2 = st.columns(2)

    with col_reg1:
        st.subheader("Regional Performance: Sales vs. Profit")
        region_df = (
            filtered_df.groupby("Region")[["SalesAmount", "ProfitAmount"]]
            .sum()
            .reset_index()
            .sort_values(by="SalesAmount", ascending=True)
        )
        fig_region = go.Figure()
        fig_region.add_trace(go.Bar(
            y=region_df["Region"],
            x=region_df["SalesAmount"],
            name="Sales ($)",
            orientation="h",
            marker_color="#3B82F6",
        ))
        fig_region.add_trace(go.Bar(
            y=region_df["Region"],
            x=region_df["ProfitAmount"],
            name="Profit ($)",
            orientation="h",
            marker_color="#10B981",
        ))
        fig_region.update_layout(
            barmode="group",
            height=320,
            margin=dict(l=20, r=20, t=30, b=30),
            legend=dict(orientation="h", y=1.05),
        )
        st.plotly_chart(fig_region, use_container_width=True)

    with col_reg2:
        st.subheader("Shipping Channel Volume & Duration")
        ship_df = (
            filtered_df.groupby("ShipModeName")
            .agg(TotalOrders=("OrderID", "nunique"), AvgShippingDays=("ShippingDurationDays", "mean"))
            .reset_index()
            .sort_values(by="TotalOrders", ascending=False)
        )
        fig_ship = px.bar(
            ship_df,
            x="ShipModeName",
            y="TotalOrders",
            text="TotalOrders",
            color="AvgShippingDays",
            color_continuous_scale="Blues",
            labels={"ShipModeName": "Ship Mode", "TotalOrders": "Total Orders", "AvgShippingDays": "Avg Days"},
        )
        fig_ship.update_traces(textposition="outside")
        fig_ship.update_layout(height=320, margin=dict(l=20, r=20, t=30, b=30))
        st.plotly_chart(fig_ship, use_container_width=True)

# ============================================================================
# PAGE 2: PRODUCT & SALES ANALYSIS
# ============================================================================
elif page == "📦 Product & Sales Analysis":
    st.markdown('<div class="main-title">Product & Sales Analysis</div>', unsafe_allow_html=True)
    st.markdown('<div class="subtitle">Item-level catalog profitability, discount sensitivity, and loss diagnostic analysis.</div>', unsafe_allow_html=True)

    # Category Hierarchy Summary
    st.subheader("Category & Sub-Category Profitability Matrix")
    cat_df = (
        filtered_df.groupby(["Category", "SubCategory"])
        .agg(
            Sales=("SalesAmount", "sum"),
            Profit=("ProfitAmount", "sum"),
            UnitsSold=("Quantity", "sum"),
            AvgDiscount=("DiscountRate", "mean"),
        )
        .reset_index()
    )
    cat_df["ProfitMargin%"] = (cat_df["Profit"] / cat_df["Sales"] * 100).round(2)
    cat_df["AvgDiscount%"] = (cat_df["AvgDiscount"] * 100).round(1)

    fig_tree = px.treemap(
        cat_df,
        path=["Category", "SubCategory"],
        values="Sales",
        color="ProfitMargin%",
        color_continuous_scale="RdYlGn",
        color_continuous_midpoint=10.0,
        title="Product Hierarchy (Area = Sales, Color = Profit Margin %)",
    )
    fig_tree.update_layout(height=420, margin=dict(l=10, r=10, t=40, b=10))
    st.plotly_chart(fig_tree, use_container_width=True)

    st.markdown("---")

    col_prod1, col_prod2 = st.columns(2)

    with col_prod1:
        st.subheader("Top 10 Most Profitable Products")
        top_prod = (
            filtered_df.groupby("ProductName")[["ProfitAmount", "SalesAmount"]]
            .sum()
            .reset_index()
            .sort_values(by="ProfitAmount", ascending=False)
            .head(10)
        )
        fig_top = px.bar(
            top_prod,
            x="ProfitAmount",
            y="ProductName",
            orientation="h",
            color="ProfitAmount",
            color_continuous_scale="Greens",
            labels={"ProfitAmount": "Total Profit ($)", "ProductName": "Product Name"},
        )
        fig_top.update_layout(yaxis=dict(autorange="reversed"), height=380, margin=dict(l=10, r=10, t=20, b=20))
        st.plotly_chart(fig_top, use_container_width=True)

    with col_prod2:
        st.subheader("Discount Sensitivity vs. Profit Margin")
        fig_scatter = px.scatter(
            filtered_df,
            x="DiscountRate",
            y="ProfitMargin",
            color="Category",
            size="Quantity",
            hover_data=["ProductName", "SubCategory", "SalesAmount", "ProfitAmount"],
            labels={"DiscountRate": "Discount Rate (0 to 1.0)", "ProfitMargin": "Profit Margin Ratio"},
        )
        fig_scatter.add_hline(y=0.0, line_dash="dash", line_color="red", annotation_text="Break-even")
        fig_scatter.update_layout(height=380, margin=dict(l=10, r=10, t=20, b=20))
        st.plotly_chart(fig_scatter, use_container_width=True)

    # Loss-making products table
    st.subheader("⚠️ Loss-Making Products Diagnostics (Negative Margin Items)")
    loss_df = cat_df[cat_df["Profit"] < 0].sort_values(by="Profit", ascending=True)
    if not loss_df.empty:
        st.dataframe(
            loss_df.style.format({
                "Sales": "${:,.2f}",
                "Profit": "${:,.2f}",
                "UnitsSold": "{:,}",
                "ProfitMargin%": "{:.2f}%",
                "AvgDiscount%": "{:.1f}%",
            }),
            use_container_width=True,
        )
    else:
        st.success("No loss-making product categories in current selection!")

# ============================================================================
# PAGE 3: CUSTOMER ANALYTICS
# ============================================================================
elif page == "👥 Customer Analytics":
    st.markdown('<div class="main-title">Customer Analytics</div>', unsafe_allow_html=True)
    st.markdown('<div class="subtitle">Account value distribution, top corporate customers, and geographic density.</div>', unsafe_allow_html=True)

    col_cust1, col_cust2 = st.columns([1, 1])

    with col_cust1:
        st.subheader("Top 10 High-Value Customers by Revenue")
        top_cust = (
            filtered_df.groupby(["CustomerID", "CustomerName", "CustomerSegment"])
            .agg(TotalSales=("SalesAmount", "sum"), TotalProfit=("ProfitAmount", "sum"), Orders=("OrderID", "nunique"))
            .reset_index()
            .sort_values(by="TotalSales", ascending=False)
            .head(10)
        )
        fig_cust = px.bar(
            top_cust,
            x="TotalSales",
            y="CustomerName",
            orientation="h",
            color="CustomerSegment",
            text="TotalSales",
            labels={"TotalSales": "Sales Revenue ($)", "CustomerName": "Customer Name"},
        )
        fig_cust.update_traces(texttemplate="$%{text:,.0f}", textposition="outside")
        fig_cust.update_layout(yaxis=dict(autorange="reversed"), height=400, margin=dict(l=10, r=10, t=20, b=20))
        st.plotly_chart(fig_cust, use_container_width=True)

    with col_cust2:
        st.subheader("Customer Segment Revenue & Margin Comparison")
        seg_summary = (
            filtered_df.groupby("CustomerSegment")
            .agg(
                Sales=("SalesAmount", "sum"),
                Profit=("ProfitAmount", "sum"),
                Orders=("OrderID", "nunique"),
                UniqueCustomers=("CustomerID", "nunique"),
            )
            .reset_index()
        )
        seg_summary["AOV"] = seg_summary["Sales"] / seg_summary["Orders"]
        seg_summary["ProfitMargin%"] = (seg_summary["Profit"] / seg_summary["Sales"] * 100).round(2)

        fig_seg_bar = go.Figure()
        fig_seg_bar.add_trace(go.Bar(
            x=seg_summary["CustomerSegment"],
            y=seg_summary["Sales"],
            name="Sales ($)",
            marker_color="#3B82F6",
        ))
        fig_seg_bar.add_trace(go.Bar(
            x=seg_summary["CustomerSegment"],
            y=seg_summary["Profit"],
            name="Profit ($)",
            marker_color="#10B981",
        ))
        fig_seg_bar.update_layout(barmode="group", height=400, margin=dict(l=20, r=20, t=20, b=20))
        st.plotly_chart(fig_seg_bar, use_container_width=True)

    st.markdown("---")

    # State-level performance
    st.subheader("State-Level Performance Ranking (Top 15 States by Sales)")
    state_df = (
        filtered_df.groupby("State")
        .agg(
            TotalSales=("SalesAmount", "sum"),
            TotalProfit=("ProfitAmount", "sum"),
            OrderCount=("OrderID", "nunique"),
        )
        .reset_index()
        .sort_values(by="TotalSales", ascending=False)
        .head(15)
    )

    fig_state = px.bar(
        state_df,
        x="State",
        y="TotalSales",
        color="TotalProfit",
        color_continuous_scale="Viridis",
        labels={"TotalSales": "Sales Revenue ($)", "TotalProfit": "Profit ($)"},
    )
    fig_state.update_layout(height=350, margin=dict(l=20, r=20, t=20, b=20))
    st.plotly_chart(fig_state, use_container_width=True)
