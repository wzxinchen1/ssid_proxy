/**
 * 简易模板引擎
 * 支持功能：
 * 1. 单向绑定（{{变量名}}）
 * 2. 事件绑定（事件名="函数名"）
 * 3. v-for 循环（v-for="item in items"）
 * 4. v-for-empty 支持（v-for-empty="无数据"）
 * 5. v-value 支持（v-value="xxx"，用于 select 标签选中匹配的 option）
 * 6. 三目运算符支持（{{条件 ? 值1 : 值2}}）
 */
export class Template {
  constructor(templateString, module) {
    this.rawTemplateString = templateString;
    this.module = module;

  }

  renderBindings(template, data) {
    const templateElement = document.createElement("template");
    templateElement.innerHTML = template;
    const vForMap = {};
    let domTree = templateElement.content.firstElementChild;
    if (template.includes("v-for")) {
      const vForElements = this._findVForElements(domTree);
      for (let index = 0; index < vForElements.length; index++) {
        const element = vForElements[index];
        const newNode = $("<" + element.tagName + " id='i_" + index + "'></" + element.tagName + ">")[0];
        element.replaceWith(newNode);
        vForMap[index] = element;
        element.remove();
      }
    }
    templateElement.innerHTML = templateElement.innerHTML.replace(/{{[\s\S]*?}}/g, (expr) => {
      // 处理三目运算符
      return this._safeEval(data, expr);
    });
    if (template.includes("v-for")) {
      domTree = templateElement.content.firstElementChild;
      for (const key in vForMap) {
        if (Object.prototype.hasOwnProperty.call(vForMap, key)) {
          const vForElement = vForMap[key];
          const placeHolderElement = domTree.querySelector("#i_" + key);
          placeHolderElement.replaceWith(vForElement);
        }
      }
    }
    return templateElement;
  }
  /**
   * 渲染模板
   * @param {object} data - 数据对象
   * @returns {HTMLElement} 渲染后的 DOM 元素
   */
  render() {
    const data = this.module.viewData;
    if (!data) {
      data = {};
    }
    const templateElement = this.renderBindings(this.rawTemplateString, data);
    this.domTree = templateElement.content.firstElementChild;
    // 检查是否有 v-for
    this.hasVFor = templateElement.innerHTML.includes('v-for');
    this.vForElements = [];
    if (this.hasVFor) {
      this.vForElements = this._findVForElements(this.domTree);
      // 处理 v-for 节点并更新模板字符串
      const processedDom = this._processVForElements(templateElement.innerHTML, this.domTree, this.vForElements, data);
      templateElement.innerHTML = processedDom.outerHTML;
    }
    this.domTree = templateElement.content.firstElementChild;
    // 克隆 DOM 树
    const clonedTree = this.domTree.cloneNode(true);
    // 处理单向绑定和事件绑定
    this._processBindings(clonedTree, data);
    return clonedTree;
  }

  /**
   * 查找所有 v-for 元素
   * @param {HTMLElement} element - 根元素
   * @returns {Array} v-for 元素列表
   */
  _findVForElements(element) {
    const vForElements = [];

    // 递归查找 v-for 属性
    const walk = (node) => {
      if (node.hasAttribute('v-for')) {
        vForElements.push(node);
        return;
      }

      // 遍历子节点
      for (const child of node.children) {
        walk(child);
      }
    };

    walk(element);
    return vForElements;
  }

  /**
   * 处理 v-for 元素
   * @param {string} template - 模板字符串
   * @param {HTMLElement} root - 根元素
   * @param {Array} vForElements - v-for 元素列表
   * @param {object} data - 数据对象
   * @returns {HTMLElement} 处理后的 DOM 元素
   */
  _processVForElements(template, root, vForElements, data) {
    for (let i = 0; i < vForElements.length; i++) {
      const element = vForElements[i];
      const vForValue = element.getAttribute('v-for');
      const vForEmpty = element.getAttribute('v-for-empty');
      const [itemVar, listVar] = vForValue.split(' in ');
      let list = [];
      if (listVar.includes(".")) {
        const listVarArray=listVar.split('.');
        list = data[listVarArray[0]][listVarArray[1]];
      } else {
        list = data[listVar.trim()];
      }
      if (!Array.isArray(list)) {
        list = [];
      }

      // 移除 v-for 和 v-for-empty 属性
      element.removeAttribute('v-for');
      if (vForEmpty) element.removeAttribute('v-for-empty');

      const fragment = document.createDocumentFragment();

      if (list.length === 0 && vForEmpty) {
        // 处理 v-for-empty
        const emptyNode = document.createElement(element.tagName === 'TR' ? 'td' : 'div');
        if (element.tagName === 'TR') {
          emptyNode.colSpan = element.querySelectorAll('td').length || 1;
          emptyNode.style.textAlign = "center";
        }
        emptyNode.textContent = vForEmpty;
        fragment.appendChild(emptyNode);
      } else {
        // 处理 v-for 数据
        for (const item of list) {
          const context = { ...data, [itemVar.trim()]: item };
          const templateElement = this.renderBindings(element.outerHTML, context);
          let newNode = templateElement.content.firstElementChild;
          const hasFor = templateElement.innerHTML.includes("v-for");
          if (hasFor) {
            const vForElements = this._findVForElements(newNode);
            const processedDom = this._processVForElements(templateElement.innerHTML, newNode, vForElements, context);
            templateElement.innerHTML = processedDom.outerHTML;
            newNode = templateElement.content.firstElementChild.cloneNode(true);
          }
          // 处理事件绑定
          this._processBindings(newNode, context);
          fragment.appendChild(newNode);
        }
      }

      // 替换原始元素
      const parentNode = element.parentNode;
      parentNode.replaceChild(fragment, element);
    }
    return root;
  }

  /**
   * 处理单向绑定和事件绑定
   * @param {HTMLElement} element - 根元素
   * @param {object} data - 数据对象
   */
  _processBindings(element, data) {
    // 处理 v-value 绑定（用于 select 标签）
    const selectElements = element.querySelectorAll('select[v-value]');
    for (const select of selectElements) {
      const valuePath = select.getAttribute('v-value');
      let value = valuePath;
      if (valuePath.includes("{{")) {
        value = this._safeEval(data, valuePath);
      }
      if (value !== undefined) {
        const options = select.querySelectorAll('option');
        for (const option of options) {
          option.selected = option.value === value;
        }
      }
      select.removeAttribute('v-value');
    }

    // 对于 checked = “非True值”的，移除checked
    const checkedElements = element.querySelectorAll('input[checked]');
    for (const checkedElement of checkedElements) {
      const checkedValue = checkedElement.getAttribute("checked");
      if (checkedValue == "0" || checkedValue == 0 || checkedValue == "false") {
        checkedElement.removeAttribute("checked");
      }
    }
  }

  /**
     * 安全表达式求值
     * @param {object} data - 数据上下文
     * @param {string} expr - 表达式字符串
     * @returns {any} 求值结果
     */
  _safeEval(data, expr) {
    // 1. 移除模板标记和首尾空格
    expr = expr.replace(/{|}/g, '').replace(/\r|\n|\\s/g, "").trim();

    return new Function(
      'sandbox',
      `with(sandbox) {
      try{
            return ${expr}; 
    }catch(e){
    console.dir(arguments);
    throw "求值失败：${expr}，详细错误"+e;
    }
        }`
    )(data);
  }
}