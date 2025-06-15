class TemplateEngine {
    compile(templateString) {
        // 包裹模板字符串以避免意外的文本节点
        const wrappedTemplate = `<template>${templateString}</template>`;
        const parser = new DOMParser();
        const doc = parser.parseFromString(wrappedTemplate, "text/html");
        const rootNode = doc.body.firstChild;

        // 提取模板内容
        const templateContent = rootNode.innerHTML;
        return {
            template: templateContent,
            dataBindings: this.extractBindings(templateContent),
            loops: this.extractLoops(rootNode),
        };
    }

    extractBindings(template) {
        // 提取 {{变量名}} 格式的绑定
        const regex = /\{\{([^}]+)\}\}/g;
        const bindings = [];
        let match;
        while ((match = regex.exec(template))) {
            bindings.push(match[1].trim());
        }
        return bindings;
    }

    extractLoops(node) {
        const loops = [];
        // 查找所有带 v-for 属性的元素
        const elements = node.querySelectorAll('[v-for]');
        elements.forEach(element => {
            const vForValue = element.getAttribute('v-for');
            const match = vForValue.match(/(\w+)\s+in\s+([\w.]+)/);
            if (match) {
                loops.push({
                    element: element.outerHTML,
                    itemVar: match[1], // 循环项变量名（如 item）
                    itemsPath: match[2], // 数据路径（如 items）
                });
                // 移除 v-for 属性，避免重复处理
                element.removeAttribute('v-for');
            }
        });
        return loops;
    }

    render(compiledTemplate, data) {
        let renderedTemplate = compiledTemplate.template;

        // 处理 v-for 循环
        compiledTemplate.loops.forEach(loop => {
            const items = this.evaluateBinding(loop.itemsPath, data) || [];
            let loopContent = '';
            items.forEach(item => {
                let itemTemplate = loop.element;
                // 替换循环项中的绑定
                const itemBindings = this.extractBindings(itemTemplate);
                itemBindings.forEach(binding => {
                    const value = this.evaluateBinding(binding, { ...data, [loop.itemVar]: item });
                    itemTemplate = itemTemplate.replace(new RegExp(`\\{\\{${binding}\\}\\}`, "g"), value);
                });
                loopContent += itemTemplate;
            });
            // 替换原始模板中的循环部分
            renderedTemplate = renderedTemplate.replace(loop.element, loopContent);
        });

        // 处理普通绑定
        compiledTemplate.dataBindings.forEach(binding => {
            const value = this.evaluateBinding(binding, data);
            renderedTemplate = renderedTemplate.replace(new RegExp(`\\{\\{${binding}\\}\\}`, "g"), value);
        });

        // 再次解析为 DOM 节点
        const parser = new DOMParser();
        const doc = parser.parseFromString(renderedTemplate, "text/html");
        return doc.body.firstChild;
    }

    evaluateBinding(binding, data) {
        // 支持简单的表达式，例如 protocol.toUpperCase()
        try {
            return new Function("data", `return data.${binding}`)(data);
        } catch (e) {
            console.error(`Failed to evaluate binding: ${binding}`, e);
            return "";
        }
    }
}
