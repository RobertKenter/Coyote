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
`include "lynx_macros.svh"

/**
 * @brief   One network port for one vFPGA
 *
 * With a network port per vFPGA (N_NET_PORTS > 1), port PORT serves region PORT alone, and its
 * stack sees that region as region 0, as in a single-vFPGA shell: requests reach the stack with
 * vfid 0, so its QP numbers are the thread ids and fit the stack's tables, and everything the
 * stack returns is given vfid PORT back. The region rides rdma_arbiter's slot 0; the other
 * slots stay idle.
 *
 *  @param PORT     Network port, and region, served
 */
module rdma_port_bind #(
    parameter integer PORT = 0
) (
    input  wire             aclk,
    input  wire             aresetn,

    // Network, port PORT
    metaIntf.m              m_rdma_sq_net,
    metaIntf.s              s_rdma_cq_net,
    metaIntf.s              s_rdma_rq_rd_net,
    metaIntf.s              s_rdma_rq_wr_net,
    AXI4S.m                 m_axis_rdma_rd_req_net,
    AXI4S.m                 m_axis_rdma_rd_rsp_net,
    AXI4S.s                 s_axis_rdma_wr_net,

    // User, region PORT
    metaIntf.s              s_rdma_sq_user,
    metaIntf.m              m_rdma_cq_user,
    metaIntf.m              m_rdma_host_cq_user,
    metaIntf.m              m_rdma_rq_rd_user,
    metaIntf.m              m_rdma_rq_wr_user,
    AXI4S.s                 s_axis_rdma_rd_req_user,
    AXI4S.s                 s_axis_rdma_rd_rsp_user,
    AXI4S.m                 m_axis_rdma_wr_user
);

localparam logic [DEST_BITS-1:0] VFID = PORT;

metaIntf #(.STYPE(dreq_t)) sq_net (.*);
metaIntf #(.STYPE(ack_t)) cq_net (.*);
metaIntf #(.STYPE(req_t)) rq_rd_net (.*);
metaIntf #(.STYPE(req_t)) rq_wr_net (.*);
metaIntf #(.STYPE(ack_t)) host_cq (.*);

metaIntf #(.STYPE(dreq_t)) sq_user [N_REGIONS] (.*);
metaIntf #(.STYPE(ack_t)) cq_user [N_REGIONS] (.*);
metaIntf #(.STYPE(req_t)) rq_rd_user [N_REGIONS] (.*);
metaIntf #(.STYPE(req_t)) rq_wr_user [N_REGIONS] (.*);
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) rd_req_user [N_REGIONS] (.*);
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) rd_rsp_user [N_REGIONS] (.*);
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) wr_user [N_REGIONS] (.*);

// To the stack: vfid 0
assign m_rdma_sq_net.valid = sq_net.valid;
assign sq_net.ready = m_rdma_sq_net.ready;
always_comb begin
    m_rdma_sq_net.data = sq_net.data;
    m_rdma_sq_net.data.req_1.vfid = 0;
    m_rdma_sq_net.data.req_2.vfid = 0;
end

// From the stack: vfid 0 whatever it carries, so the arbiter picks slot 0
assign cq_net.valid = s_rdma_cq_net.valid;
assign s_rdma_cq_net.ready = cq_net.ready;
always_comb begin
    cq_net.data = s_rdma_cq_net.data;
    cq_net.data.vfid = 0;
end

assign rq_rd_net.valid = s_rdma_rq_rd_net.valid;
assign s_rdma_rq_rd_net.ready = rq_rd_net.ready;
always_comb begin
    rq_rd_net.data = s_rdma_rq_rd_net.data;
    rq_rd_net.data.vfid = 0;
end

assign rq_wr_net.valid = s_rdma_rq_wr_net.valid;
assign s_rdma_rq_wr_net.ready = rq_wr_net.ready;
always_comb begin
    rq_wr_net.data = s_rdma_rq_wr_net.data;
    rq_wr_net.data.vfid = 0;
end

rdma_arbiter inst_arbiter (
    .aclk(aclk),
    .aresetn(aresetn),

    .m_rdma_sq_net(sq_net),
    .s_rdma_cq_net(cq_net),
    .s_rdma_rq_rd_net(rq_rd_net),
    .s_rdma_rq_wr_net(rq_wr_net),
    .m_axis_rdma_rd_req_net(m_axis_rdma_rd_req_net),
    .m_axis_rdma_rd_rsp_net(m_axis_rdma_rd_rsp_net),
    .s_axis_rdma_wr_net(s_axis_rdma_wr_net),

    .s_rdma_sq_user(sq_user),
    .m_rdma_cq_user(cq_user),
    .m_rdma_host_cq_user(host_cq),
    .m_rdma_rq_rd_user(rq_rd_user),
    .m_rdma_rq_wr_user(rq_wr_user),
    .s_axis_rdma_rd_req_user(rd_req_user),
    .s_axis_rdma_rd_rsp_user(rd_rsp_user),
    .m_axis_rdma_wr_user(wr_user)
);

// Slot 0: the region, which gets its own vfid back
`META_ASSIGN(s_rdma_sq_user, sq_user[0])
`AXIS_ASSIGN(s_axis_rdma_rd_req_user, rd_req_user[0])
`AXIS_ASSIGN(s_axis_rdma_rd_rsp_user, rd_rsp_user[0])
`AXIS_ASSIGN(wr_user[0], m_axis_rdma_wr_user)

assign m_rdma_cq_user.valid = cq_user[0].valid;
assign cq_user[0].ready = m_rdma_cq_user.ready;
always_comb begin
    m_rdma_cq_user.data = cq_user[0].data;
    m_rdma_cq_user.data.vfid = VFID;
end

assign m_rdma_host_cq_user.valid = host_cq.valid;
assign host_cq.ready = m_rdma_host_cq_user.ready;
always_comb begin
    m_rdma_host_cq_user.data = host_cq.data;
    m_rdma_host_cq_user.data.vfid = VFID;
end

assign m_rdma_rq_rd_user.valid = rq_rd_user[0].valid;
assign rq_rd_user[0].ready = m_rdma_rq_rd_user.ready;
always_comb begin
    m_rdma_rq_rd_user.data = rq_rd_user[0].data;
    m_rdma_rq_rd_user.data.vfid = VFID;
end

assign m_rdma_rq_wr_user.valid = rq_wr_user[0].valid;
assign rq_wr_user[0].ready = m_rdma_rq_wr_user.ready;
always_comb begin
    m_rdma_rq_wr_user.data = rq_wr_user[0].data;
    m_rdma_rq_wr_user.data.vfid = VFID;
end

// The other slots: nothing to send, anything received is dropped (the stack only returns slot 0)
for (genvar i = 1; i < N_REGIONS; i++) begin : g_idle
    assign sq_user[i].valid = 1'b0;
    assign sq_user[i].data = 0;
    assign cq_user[i].ready = 1'b1;
    assign rq_rd_user[i].ready = 1'b1;
    assign rq_wr_user[i].ready = 1'b1;
    `AXIS_TIE_OFF_M(rd_req_user[i])
    `AXIS_TIE_OFF_M(rd_rsp_user[i])
    `AXIS_TIE_OFF_S(wr_user[i])
end

endmodule
