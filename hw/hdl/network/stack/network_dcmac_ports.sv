/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2026, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

`include "axi_macros.svh"

/**
 * @brief   Two 200G ports on one DCMAC
 *
 * The network module for N_NET_PORTS = 2 or 4 on the V80, one instance per DCMAC. DCMAC 0 is the
 * one QSFP port 0 uses (DCMAC_X1Y1, GTM banks 209 and 210, right-hand cages); DCMAC 1 is the other
 * (DCMAC_X0Y2, banks 111 and 112, left-hand cages), for ports 2 and 3. Each runs two 200GAUI-4
 * ports, one per cage, from its pair's reference clock. Each port gets network_module_dcmac's
 * padding and register stages; the block design (cr_dcmac.tcl: dcmac_versal_axis_ports, and
 * dcmac_versal_axis_ports_1 for DCMAC 1) crosses both to aclk.
 */
module network_dcmac_ports #(
    parameter integer DCMAC = 0
) (
    input  wire         aclk,
    input  wire         aresetn,

    // GT: both ports' lanes (gt0, gt1: this DCMAC's first and second port), one reference clock
    input  wire         gt_refclk_p,
    input  wire         gt_refclk_n,
    input  wire [3:0]   gt0_rxp_in,
    input  wire [3:0]   gt0_rxn_in,
    output wire [3:0]   gt0_txp_out,
    output wire [3:0]   gt0_txn_out,
    input  wire [3:0]   gt1_rxp_in,
    input  wire [3:0]   gt1_rxn_in,
    output wire [3:0]   gt1_txp_out,
    output wire [3:0]   gt1_txn_out,

    // One stream pair per port
    AXI4S.m             m_axis_net_rx [2],
    AXI4S.s             s_axis_net_tx [2],

    // DCMAC reset sequence and GT status (unsynchronised; see shell_slave's DCMAC_STATUS_REG):
    // [23:0] dcmac_reset_ctrl status, [29:24] quad 1 power good, RX done, TX done, then quad 0's
    output logic [31:0] m_status
);

if (N_NET_PORTS != 2 && N_NET_PORTS != 4) begin
    $error("network_dcmac_ports: two ports per DCMAC, N_NET_PORTS 2 or 4");
end
if (DCMAC > 1 || 2 * DCMAC >= N_NET_PORTS) begin
    $error("network_dcmac_ports: no DCMAC %0d with %0d ports", DCMAC, N_NET_PORTS);
end

AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) tx_axis_int [2] (.aclk(aclk), .aresetn(aresetn));
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) tx_axis_dcmac [2] (.aclk(aclk), .aresetn(aresetn));
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) rx_axis_dcmac [2] (.aclk(aclk), .aresetn(aresetn));

for (genvar p = 0; p < 2; p++) begin : g_port
    // TX
    ethernet_frame_padding_512_ip inst_padding (
        .ap_clk(aclk),
        .ap_rst_n(aresetn),
        .m_axis_TVALID(tx_axis_int[p].tvalid),
        .m_axis_TREADY(tx_axis_int[p].tready),
        .m_axis_TDATA(tx_axis_int[p].tdata),
        .m_axis_TKEEP(tx_axis_int[p].tkeep),
        .m_axis_TLAST(tx_axis_int[p].tlast),
        .s_axis_TVALID(s_axis_net_tx[p].tvalid),
        .s_axis_TREADY(s_axis_net_tx[p].tready),
        .s_axis_TDATA(s_axis_net_tx[p].tdata),
        .s_axis_TKEEP(s_axis_net_tx[p].tkeep),
        .s_axis_TLAST(s_axis_net_tx[p].tlast)
    );

    axis_reg_array #(.N_STAGES(2)) inst_reg_tx (.aclk(aclk), .aresetn(aresetn), .s_axis(tx_axis_int[p]), .m_axis(tx_axis_dcmac[p]));

    // RX
    axis_reg_array #(.N_STAGES(2)) inst_reg_rx (.aclk(aclk), .aresetn(aresetn), .s_axis(rx_axis_dcmac[p]), .m_axis(m_axis_net_rx[p]));
end

logic [23:0] ctrl_status;
logic [1:0] gt_tx_done, gt_rx_done, gt_powergood;

assign m_status = {2'b00, gt_powergood[1], gt_rx_done[1], gt_tx_done[1],
                   gt_powergood[0], gt_rx_done[0], gt_tx_done[0], ctrl_status};

// Each DCMAC is its own block design, which sets the DCMAC's site
if (DCMAC == 0) begin : g_dcmac
    dcmac_versal_axis_ports inst_dcmac (
        .aclk(aclk),
        .aresetn(aresetn),

        .dcmac_status(ctrl_status),
        .gt0_tx_done(gt_tx_done[0]),
        .gt0_rx_done(gt_rx_done[0]),
        .gt0_powergood(gt_powergood[0]),
        .gt1_tx_done(gt_tx_done[1]),
        .gt1_rx_done(gt_rx_done[1]),
        .gt1_powergood(gt_powergood[1]),

        .s_axis_tx_0_tdata(tx_axis_dcmac[0].tdata),
        .s_axis_tx_0_tkeep(tx_axis_dcmac[0].tkeep),
        .s_axis_tx_0_tlast(tx_axis_dcmac[0].tlast),
        .s_axis_tx_0_tready(tx_axis_dcmac[0].tready),
        .s_axis_tx_0_tvalid(tx_axis_dcmac[0].tvalid),
        .m_axis_rx_0_tdata(rx_axis_dcmac[0].tdata),
        .m_axis_rx_0_tkeep(rx_axis_dcmac[0].tkeep),
        .m_axis_rx_0_tlast(rx_axis_dcmac[0].tlast),
        .m_axis_rx_0_tready(rx_axis_dcmac[0].tready),
        .m_axis_rx_0_tvalid(rx_axis_dcmac[0].tvalid),

        .s_axis_tx_1_tdata(tx_axis_dcmac[1].tdata),
        .s_axis_tx_1_tkeep(tx_axis_dcmac[1].tkeep),
        .s_axis_tx_1_tlast(tx_axis_dcmac[1].tlast),
        .s_axis_tx_1_tready(tx_axis_dcmac[1].tready),
        .s_axis_tx_1_tvalid(tx_axis_dcmac[1].tvalid),
        .m_axis_rx_1_tdata(rx_axis_dcmac[1].tdata),
        .m_axis_rx_1_tkeep(rx_axis_dcmac[1].tkeep),
        .m_axis_rx_1_tlast(rx_axis_dcmac[1].tlast),
        .m_axis_rx_1_tready(rx_axis_dcmac[1].tready),
        .m_axis_rx_1_tvalid(rx_axis_dcmac[1].tvalid),

        .gt_clk_clk_n(gt_refclk_n),
        .gt_clk_clk_p(gt_refclk_p),

        .gt0_grx_n(gt0_rxn_in),
        .gt0_grx_p(gt0_rxp_in),
        .gt0_gtx_n(gt0_txn_out),
        .gt0_gtx_p(gt0_txp_out),
        .gt1_grx_n(gt1_rxn_in),
        .gt1_grx_p(gt1_rxp_in),
        .gt1_gtx_n(gt1_txn_out),
        .gt1_gtx_p(gt1_txp_out)
    );
end
else begin : g_dcmac
    dcmac_versal_axis_ports_1 inst_dcmac (
        .aclk(aclk),
        .aresetn(aresetn),

        .dcmac_status(ctrl_status),
        .gt0_tx_done(gt_tx_done[0]),
        .gt0_rx_done(gt_rx_done[0]),
        .gt0_powergood(gt_powergood[0]),
        .gt1_tx_done(gt_tx_done[1]),
        .gt1_rx_done(gt_rx_done[1]),
        .gt1_powergood(gt_powergood[1]),

        .s_axis_tx_0_tdata(tx_axis_dcmac[0].tdata),
        .s_axis_tx_0_tkeep(tx_axis_dcmac[0].tkeep),
        .s_axis_tx_0_tlast(tx_axis_dcmac[0].tlast),
        .s_axis_tx_0_tready(tx_axis_dcmac[0].tready),
        .s_axis_tx_0_tvalid(tx_axis_dcmac[0].tvalid),
        .m_axis_rx_0_tdata(rx_axis_dcmac[0].tdata),
        .m_axis_rx_0_tkeep(rx_axis_dcmac[0].tkeep),
        .m_axis_rx_0_tlast(rx_axis_dcmac[0].tlast),
        .m_axis_rx_0_tready(rx_axis_dcmac[0].tready),
        .m_axis_rx_0_tvalid(rx_axis_dcmac[0].tvalid),

        .s_axis_tx_1_tdata(tx_axis_dcmac[1].tdata),
        .s_axis_tx_1_tkeep(tx_axis_dcmac[1].tkeep),
        .s_axis_tx_1_tlast(tx_axis_dcmac[1].tlast),
        .s_axis_tx_1_tready(tx_axis_dcmac[1].tready),
        .s_axis_tx_1_tvalid(tx_axis_dcmac[1].tvalid),
        .m_axis_rx_1_tdata(rx_axis_dcmac[1].tdata),
        .m_axis_rx_1_tkeep(rx_axis_dcmac[1].tkeep),
        .m_axis_rx_1_tlast(rx_axis_dcmac[1].tlast),
        .m_axis_rx_1_tready(rx_axis_dcmac[1].tready),
        .m_axis_rx_1_tvalid(rx_axis_dcmac[1].tvalid),

        .gt_clk_clk_n(gt_refclk_n),
        .gt_clk_clk_p(gt_refclk_p),

        .gt0_grx_n(gt0_rxn_in),
        .gt0_grx_p(gt0_rxp_in),
        .gt0_gtx_n(gt0_txn_out),
        .gt0_gtx_p(gt0_txp_out),
        .gt1_grx_n(gt1_rxn_in),
        .gt1_grx_p(gt1_rxp_in),
        .gt1_gtx_n(gt1_txn_out),
        .gt1_gtx_p(gt1_txp_out)
    );
end

endmodule
